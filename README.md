# Blazer

Explore your data. Easily create charts and dashboards, and share the results with your team.

[Try it out](https://blazerme.herokuapp.com)

[![Screenshot](https://blazerme.herokuapp.com/assets/screenshot-18d79092e635b4b220f57ff7a1ecea41.png)](https://blazerme.herokuapp.com)

:tangerine: Battle-tested at [Instacart](https://www.instacart.com/opensource)

**Blazer 1.0 was recently released!** See the [instructions for upgrading](#10)

## Features

- Works with PostgreSQL, MySQL, and Redshift
- **Charts** - visualize the data
- **Dashboards** - see queries all in one place
- **Checks & Alerts** - get emailed when bad data appears [master]
- **Variables** - run the same queries with different values
- **Audits** - all queries are tracked
- **Secure** - works with your authentication system

## Variables

[demo]

Create queries with variables

```sql
SELECT COUNT(*) FROM users WHERE gender = {gender}
```

### Smart Variables

[demo]

Supposed you have this query

```sql
SELECT COUNT(*) FROM users WHERE city_id = {city_id}
```

Instead of remembering each city’s id, users can select cities by name.

Add a smart variable with:

```yml
smart_variables:
  city_id: "SELECT id, name FROM cities ORDER BY name ASC"
```

The first column is the value of the variable, and the second column is the label.

## Results

### Linked Columns

[demo]

Link results to other pages in your apps or around the web. Specify a column name and where it should link to. You can use the value of the result with `{value}`.

```yml
linked_columns:
  user_id: "/admin/users/{value}"
  ip_address: "http://www.infosniper.net/index.php?ip_address={value}"
```

### Smart Columns

[demo]

```sql
SELECT name, city_id FROM users
```

See which city the user belongs to without a join.

```yml
smart_columns:
  city_id: "SELECT id, name FROM cities WHERE id IN {value}"
```

## Charts

Blazer will automatically generate charts based on the types of the columns returned in your query.

### Line Chart

There are two ways to generate line charts.

2+ columns - timestamp, numeric(s) [demo]

```sql
SELECT gd_week(created_at), COUNT(*) FROM users GROUP BY 1
```

3 columns - timestamp, string, numeric [demo]

```sql
SELECT gd_week(created_at), gender, AVG(age) FROM users GROUP BY 1, 2
```

### Pie Chart

2 columns - string, numeric [demo]

```sql
SELECT gender, COUNT(*) FROM users GROUP BY 1
```

## Audits

Each query run creates a `Blazer::Audit`.

## Dashboards

[demo]

Combine multiple queries into a dashboard.

If the query has a chart, the chart is shown. Otherwise, you’ll see a table.

If any queries have variables, they will show up on the dashboard.

## Checks

[demo]

Checks give you a centralized place to see the health of your data.

Create a query to identify bad rows.

```sql
SELECT * FROM events WHERE started_at > ended_at
```

Then create check with optional emails if you want to be notified.

## Installation

Add this line to your application’s Gemfile:

```ruby
gem 'blazer'
```

Run:

```sh
rails g blazer:install
rake db:migrate
```

And mount the dashboard in your `config/routes.rb`:

```ruby
mount Blazer::Engine, at: "blazer"
```

For production, specify your database:

```ruby
ENV["BLAZER_DATABASE_URL"] = "postgres://user:password@hostname:5432/database"
```

Blazer tries to protect against queries which modify data (by running each query in a transaction and rolling it back), but a safer approach is to use a read only user.  [See how to create one](#permissions).

#### Checks (optional)

Be sure to set a host in `config/environments/production.rb` for emails to work.

```ruby
config.action_mailer.default_url_options = {host: "blazerme.herokuapp.com"}
```

Schedule checks to run every hour (with cron, [Heroku Scheduler](https://addons.heroku.com/scheduler), etc).

```sh
rake blazer:run_checks
```

You can also set up failing checks to be sent once a day (or whatever you prefer).

```sh
rake blazer:send_failing_checks
```

## Permissions

### PostgreSQL

Create a user with read only permissions:

```sql
BEGIN;
CREATE ROLE blazer LOGIN PASSWORD 'secret123';
GRANT CONNECT ON DATABASE database_name TO blazer;
GRANT USAGE ON SCHEMA public TO blazer;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO blazer;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO blazer;
COMMIT;
```

### MySQL

Create a user with read only permissions:

```sql
GRANT SELECT, SHOW VIEW ON database_name.* TO blazer@’127.0.0.1′ IDENTIFIED BY ‘secret123‘;
FLUSH PRIVILEGES;
```

### Sensitive Data

To protect sensitive info like password hashes and access tokens, use views. Documentation coming soon.

## Authentication

Don’t forget to protect the dashboard in production.

### Basic Authentication

Set the following variables in your environment or an initializer.

```ruby
ENV["BLAZER_USERNAME"] = "andrew"
ENV["BLAZER_PASSWORD"] = "secret"
```

### Devise

```ruby
authenticate :user, lambda { |user| user.admin? } do
  mount Blazer::Engine, at: "blazer"
end
```

## Customization

Change time zone

```ruby
Blazer.time_zone = "Pacific Time (US & Canada)"
```

Change timeout *PostgreSQL only*

```ruby
Blazer.timeout = 10 # defaults to 15
```

Turn off audits

```ruby
Blazer.audit = false
```

Custom user class

```ruby
Blazer.user_class = "Admin"
```

Customize user name

```ruby
Blazer.user_name = :first_name
```

## Useful Tools

For an easy way to group by day, week, month, and more with correct time zones, check out [Groupdate](https://github.com/ankane/groupdate.sql).

## Redshift

Add [activerecord4-redshift-adapter](https://github.com/aamine/activerecord4-redshift-adapter) to your Gemfile and set:

```ruby
ENV["BLAZER_DATABASE_URL"] = "redshift://user:password@hostname:5439/database"
```

## Upgrading

### 1.0

Blazer 1.0 brings a number of new features:

- multiple data sources, including Redshift
- dashboards
- checks

To upgrade, run

```sh
bundle update blazer
```

Create a migration

```sh
rails g migration upgrade_blazer_to_1_0
```

with

```ruby
add_column :blazer_queries, :data_source, :string
add_column :blazer_audits, :data_source, :string

create_table :blazer_dashboards do |t|
  t.text :name
  t.timestamps
end

create_table :blazer_dashboard_queries do |t|
  t.references :dashboard
  t.references :query
  t.integer :position
  t.timestamps
end

create_table :blazer_checks do |t|
  t.references :query
  t.string :state
  t.text :emails
  t.timestamps
end
```

And run

```sh
rake db:migrate
```

Update `config/blazer.yml` with

```yml
# see https://github.com/ankane/blazer for more info

# data sources
data_sources:
  main:
    url: <%%= ENV["BLAZER_DATABASE_URL"] %>

    timeout: 15

    smart_variables:
      # zone_id: "SELECT id, name FROM zones ORDER BY name ASC"

    linked_columns:
      # user_id: "/admin/users/{value}"

    smart_columns:
      # user_id: "SELECT id, name FROM users WHERE id IN {value}"

# create audits
audit: true

# change the time zone
# time_zone: "Pacific Time (US & Canada)"

# class name of the user model
# user_class: User

# method name for the user model
# user_name: name
```

## TODO

- advanced permissions
- standalone version
- better navigation

## History

View the [changelog](https://github.com/ankane/blazer/blob/master/CHANGELOG.md)

## Thanks

Blazer uses a number of awesome, open source projects.

- [Rails](https://github.com/rails/rails/)
- [jQuery](https://github.com/jquery/jquery)
- [Bootstrap](https://github.com/twbs/bootstrap)
- [Selectize](https://github.com/brianreavis/selectize.js)
- [List.js](https://github.com/javve/list.js)
- [StickyTableHeaders](https://github.com/jmosbech/StickyTableHeaders)
- [Stupid jQuery Table Sort](https://github.com/joequery/Stupid-Table-Plugin)
- [Date Range Picker](https://github.com/dangrossman/bootstrap-daterangepicker)

Created by [ankane](https://github.com/ankane) and [righi](https://github.com/righi)

Demo data from [MovieLens](http://grouplens.org/datasets/movielens/).

## Contributing

Everyone is encouraged to help improve this project. Here are a few ways you can help:

- [Report bugs](https://github.com/ankane/blazer/issues)
- Fix bugs and [submit pull requests](https://github.com/ankane/blazer/pulls)
- Write, clarify, or fix documentation
- Suggest or add new features
