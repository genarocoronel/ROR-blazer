module Blazer
  class UploadsController < BaseController
    before_action :set_upload, only: [:show, :edit, :update, :destroy]

    def index
      @uploads = Blazer::Upload.order(:table)
    end

    def new
      @upload = Blazer::Upload.new
    end

    def create
      @upload = Blazer::Upload.new(upload_params)
      # use creator_id instead of creator
      # since we setup association without checking if column exists
      @upload.creator = blazer_user if @upload.respond_to?(:creator_id=) && blazer_user

      success = params.require(:upload).key?(:file)
      if success
        Blazer::Upload.transaction do
          success = @upload.save
          if success
            begin
              update_file(@upload)
            rescue CSV::MalformedCSVError, Blazer::UploadError => e
              @upload.errors.add(:base, e.message)
              success = false
              raise ActiveRecord::Rollback
            end
          end
        end
      else
        @upload.errors.add(:base, "File can't be blank")
      end

      if success
        redirect_to upload_path(@upload)
      else
        render_errors @upload
      end
    end

    def show
      redirect_to new_query_path(upload_id: @upload.id)
    end

    def edit
    end

    def update
      original_table = @upload.table
      @upload.assign_attributes(upload_params)

      success = nil
      Blazer::Upload.transaction do
        success = @upload.save
        if success
          if params.require(:upload).key?(:file)
            begin
              update_file(@upload, drop: original_table)
            rescue CSV::MalformedCSVError, Blazer::UploadError => e
              @upload.errors.add(:base, e.message)
              success = false
              raise ActiveRecord::Rollback
            end
          elsif @upload.table != original_table
            Blazer.uploads_connection.execute("ALTER TABLE #{Blazer.uploads_table_name(original_table)} RENAME TO #{Blazer.uploads_connection.quote_table_name(@upload.table)}")
          end
        end
      end

      if success
        redirect_to upload_path(@upload)
      else
        render_errors @upload
      end
    end

    def destroy
      Blazer.uploads_connection.execute("DROP TABLE IF EXISTS #{@upload.table_name}")
      @upload.destroy
      redirect_to uploads_path
    end

    private

      def update_file(upload, drop: nil)
        file = params.require(:upload).fetch(:file)
        raise Blazer::UploadError, "File is not a CSV" if file.content_type != "text/csv"
        contents = file.read
        rows = CSV.parse(contents, converters: %i[numeric date])
        columns = rows.shift.map(&:to_s)
        column_types =
          columns.size.times.map do |i|
            values = rows.map { |r| r[i] }.uniq.compact
            if values.all? { |v| v.is_a?(Integer) }
              "bigint"
            elsif values.all? { |v| v.is_a?(Numeric) }
              "decimal"
            elsif values.all? { |v| v.is_a?(Time) }
              "timestamp"
            elsif values.all? { |v| v.is_a?(Date) }
              "date"
            else
              "text"
            end
          end

        Blazer.uploads_connection.transaction do
          Blazer.uploads_connection.execute("DROP TABLE IF EXISTS #{Blazer.uploads_table_name(drop)}") if drop
          Blazer.uploads_connection.execute("CREATE TABLE #{upload.table_name} (#{columns.map.with_index { |c, i| "#{Blazer.uploads_connection.quote_column_name(c)} #{column_types[i]}" }.join(", ")})")
          Blazer.uploads_connection.raw_connection.copy_data("COPY #{upload.table_name} FROM STDIN CSV HEADER") do
            Blazer.uploads_connection.raw_connection.put_copy_data(contents)
          end
        end
      end

      def upload_params
        params.require(:upload).slice(:table).permit(:table)
      end

      def set_upload
        @upload = Blazer::Upload.find(params[:id])
      end
  end
end
