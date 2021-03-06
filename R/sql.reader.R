#' Read a database described in a .sql file.
#'
#' This function will load data from a SQL database based on configuration
#' information found in the specified .sql file. The .sql file must specify
#' a database to be accessed. All tables from the database, one specific tables
#' or one specific query against any set of tables may be executed to generate
#' a data set.
#'
#' queries can support string interpolation to execute code snippets. This is used
#' to create queries that depend on data from other sources. Code delimited is @@{...}
#'
#' Example: query: SELECT * FROM my_table WHERE id IN (@@{paste(ids, collapse = ',')}).
#' Here ids is data previously loaded into ProjectTemplate
#'
#' Examples of the DCF format and settings used in a .sql file are shown
#' below:
#'
#' Example 1
#' type: mysql
#' user: sample_user
#' password: sample_password
#' host: localhost
#' dbname: sample_database
#' table: sample_table
#'
#' Example 2
#' type: mysql
#' user: sample_user
#' password: sample_password
#' host: localhost
#' port: 3306
#' socket: /Applications/MAMP/tmp/mysql/mysql.sock
#' dbname: sample_database
#' table: sample_table
#'
#' Example 3
#' type: sqlite
#' dbname: /path/to/sample_database
#' table: sample_table
#'
#' Example 4
#' type: sqlite
#' dbname: /path/to/sample_database
#' query: SELECT * FROM users WHERE user_active == 1
#'
#' Example 5
#' type: sqlite
#' dbname: /path/to/sample_database
#' table: *
#'
#' Example 6
#' type: postgres
#' user: sample_user
#' password: sample_password
#' host: localhost
#' dbname: sample_database
#' table: sample_table
#'
#' Example 7
#' type: odbc
#' dsn: sample_dsn
#' user: sample_user
#' password: sample_password
#' dbname: sample_database
#' query: SELECT * FROM sample_table
#'
#' Example 8
#' type: oracle
#' user: sample_user
#' password: sample_password
#' dbname: sample_database
#' table: sample_table
#'
#' Example 9
#' type: jdbc
#' class: oracle.jdbc.OracleDriver
#' classpath: /path/to/ojdbc5.jar (or set in CLASSPATH)
#' user: scott
#' password: tiger
#' url: jdbc:oracle:thin:@@myhost:1521:orcl
#' query: select * from emp
#'
#' Example 10
#' type: heroku
#' classpath: /path/to/jdbc4.jar (or set in CLASSPATH)
#' user: scott
#' password: tiger
#' host: heroku.postgres.url
#' port: 1234
#' dbname: herokudb 
#' query: select * from emp
#'
#' @param data.file The name of the data file to be read.
#' @param filename The path to the data set to be loaded.
#' @param variable.name The name to be assigned to in the global environment.
#'
#' @return No value is returned; this function is called for its side effects.
#'
#' @examples
#' library('ProjectTemplate')
#'
#' \dontrun{sql.reader('example.sql', 'data/example.sql', 'example')}
#'
#' @include require.package.R
sql.reader <- function(data.file, filename, variable.name)
{
  database.info <- ProjectTemplate:::translate.dcf(filename)

  if (! is.null(database.info[['connection']]))
  {
    connection_filename <- paste("data/", database.info[['connection']],".sql-connection", sep="")
    connection.info <- ProjectTemplate:::translate.dcf(connection_filename)

    # Allow .sql to override options defined in .connection
    database.info <- modifyList(connection.info, database.info) 
  }

  if (! (database.info[['type']] %in% c('mysql', 'sqlite', 'odbc', 'postgres', 'oracle', 'jdbc', 'heroku')))
  {
    warning('Only databases reachable through RMySQL, RSQLite, RODBC ROracle or RPostgreSQL are currently supported.')
    assign(variable.name,
           NULL,
           envir = .GlobalEnv)
    return()
  }

  # Draft code for ODBC support.
  if (database.info[['type']] == 'odbc')
  {
    library('RODBC')
    connection.string <- paste('DSN=', database.info[['dsn']], ';',
                               'UID=', database.info[['user']], ';',
                               'PWD=', database.info[['password']], ';',
                               'DATABASE=', database.info['dbname'],
                               sep = '')
    connection <- odbcDriverConnect(connection.string)
    results <- sqlQuery(connection, database.info[['query']])
    odbcClose(connection)
    assign(variable.name,
           results,
           envir = .GlobalEnv)
    return()
  }
  
  if (database.info[['type']] == 'mysql')
  {
    library('RMySQL')
    mysql.driver <- dbDriver("MySQL")
    
    # Default value for 'port' in mysqlNewConnection is 0.
    if (is.null(database.info[['port']]))
    {
      database.info[['port']] <- 0
    }
    
    connection <- dbConnect(mysql.driver,
                            user = database.info[['user']],
                            password = database.info[['password']],
                            host = database.info[['host']],
                            dbname = database.info[['dbname']],
                            port = as.integer(database.info[['port']]),
                            unix.socket = database.info[['socket']])
    dbGetQuery(connection, "SET NAMES 'utf8'") # Switch to utf-8 strings
  }

  if (database.info[['type']] == 'sqlite')
  {
    library('RSQLite')
    sqlite.driver <- dbDriver("SQLite")

    connection <- dbConnect(sqlite.driver,
                            dbname = database.info[['dbname']])
  }

  if (database.info[['type']] == 'postgres')
  {
    library('RPostgreSQL')
    mysql.driver <- dbDriver("PostgreSQL")

    connection <- dbConnect(mysql.driver,
                            user = database.info[['user']],
                            password = database.info[['password']],
                            host = database.info[['host']],
                            dbname = database.info[['dbname']])
  }

  if (database.info[['type']] == 'oracle')
  {
    library('RMySQL')
    oracle.driver <- dbDriver("Oracle")
    
    # Default value for 'port' in mysqlNewConnection is 0.
    if (is.null(database.info[['port']]))
    {
      database.info[['port']] <- 0
    }
    
    connection <- dbConnect(oracle.driver,
                            user = database.info[['user']],
                            password = database.info[['password']],
                            dbname = database.info[['dbname']])
  }

  if (database.info[['type']] == 'jdbc')
  {
    library('RJDBC')

    ident.quote <- NA
    if('identquote' %in% names(database.info))
       ident.quote <- database.info[['identquote']]
    
    if(is.null(database.info[['classpath']])) {
      database.info[['classpath']] = ''
    }

    rjdbc.driver <- JDBC(database.info[['class']], database.info[['classpath']], ident.quote)
    connection <- dbConnect(rjdbc.driver,
                            database.info[['url']],
                            user = database.info[['user']],
                            password = database.info[['password']])
  }

  if (database.info[['type']] == 'heroku')
  {
    library('RJDBC')
    
    if(is.null(database.info[['classpath']])) {
      database.info[['classpath']] <- ''
  }

    database.info[['class']] <- 'org.postgresql.Driver'
    
    database.info[['url']] <- paste('jdbc:postgresql://', database.info[['host']], 
        ':', database.info[['port']], 
        '/', database.info[['dbname']], 
        '?ssl=true&sslfactory=org.postgresql.ssl.NonValidatingFactory', sep = '')
    
    rjdbc.driver <- JDBC(database.info[['class']], database.info[['classpath']])
    connection <- dbConnect(rjdbc.driver,
                            database.info[['url']],
                            user = database.info[['user']],
                            password = database.info[['password']])
  }

  # Added support for queries.
  # User should specify either a table name or a query to execute, but not both.
  table <- database.info[['table']]
  query <- database.info[['query']]
  
  # If both a table and a query are specified, favor the query.
  if (! is.null(table) && ! is.null(query))
  {
      warning(paste("'query' parameter in ",
                    filename,
                    " overrides 'table' parameter.",
                    sep = ''))
      table <- NULL
  }

  if (is.null(table) && is.null(query))
  {
    warning("Either 'table' or 'query' must be specified in a .sql file")
    return()
  }
  
  if (! is.null(table) && table == '*')
  {
    tables <- dbListTables(connection)
    for (table in tables)
    {
      message(paste('  Loading table:', table))
      
      data.parcel <- dbReadTable(connection,
                                 table,
                                 row.names = NULL)
    
      assign(ProjectTemplate:::clean.variable.name(table),
             data.parcel,
             envir = .GlobalEnv)
    }
  }
  
  # If table is specified, read the whole table.
  # Othwrwise, execute the specified query.
  if (! is.null(table) && table != '*')
  {
    if (dbExistsTable(connection, table))
    {
      data.parcel <- dbReadTable(connection,
                                 table,
                                 row.names = NULL)
      
      assign(variable.name,
             data.parcel,
             envir = .GlobalEnv)
    }
    else
    {
      warning(paste('Table not found:', table))
      return()
    }
  }

  if (! is.null(query))
  {
    if (length(grep('\\@\\{.*\\}', query)) != 0) {
      # Do string interpolation
      require.package('GetoptLong')
      query <- qq(query)
    }
    data.parcel <- try(dbGetQuery(connection, query))
    err <- dbGetException(connection)
    
    if (class(data.parcel) == 'data.frame' && (length(err) == 0 || err$errorNum == 0))
    {
      assign(variable.name,
             data.parcel,
             envir = .GlobalEnv)
    }
    else
    {
      warning(paste("Error loading '",
                    variable.name,
                    "' with query '",
                    query,
                    "'\n    '",
                    err$errorNum,
                    "-",
                    err$errorMsg,
                    "'",
                    sep = ''))
      return()
    }
  }

  # If the table exists but is empty, do not create a variable.
  # Or if the query returned no results, do not create a variable.
  if (nrow(data.parcel) == 0)
  {
    assign(variable.name,
           NULL,
           envir = .GlobalEnv)
    return()
  }

  # Disconnect from database resources. Warn if failure.
  disconnect.success <- dbDisconnect(connection)

  if (! disconnect.success)
  {
    warning(paste('Unable to disconnect from database:',
                  database.info[['dbname']]))
  }
}
