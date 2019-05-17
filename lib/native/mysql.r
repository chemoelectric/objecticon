#passthru #undef column
#passthru #undef list_push
#passthru #include "mysql.h"

static void field_to_list(MYSQL_FIELD *field, dptr res);

#begdef GetSelfMySql()
MYSQL *self_mysql;
dptr self_mysql_dptr;
static struct inline_field_cache self_mysql_ic;
self_mysql_dptr = c_get_instance_data(&self, (dptr)&ptrf, &self_mysql_ic);
if (!self_mysql_dptr)
    syserr("Missing ptr field");
if (is:null(*self_mysql_dptr))
    runerr(219, self);
self_mysql = (MYSQL*)IntVal(*self_mysql_dptr);
#enddef

#begdef GetSelfMySqlRes()
MYSQL_RES *self_mysql_res;
dptr self_mysql_res_dptr;
static struct inline_field_cache self_mysql_res_ic;
self_mysql_res_dptr = c_get_instance_data(&self, (dptr)&ptrf, &self_mysql_res_ic);
if (!self_mysql_res_dptr)
    syserr("Missing ptr field");
if (is:null(*self_mysql_res_dptr))
    runerr(219, self);
self_mysql_res = (MYSQL_RES*)IntVal(*self_mysql_res_dptr);
#enddef

static void on_mysql_error(MYSQL *p)
{
    whyf("%s (mysql_errno=%d)", mysql_error(p), mysql_errno(p));
}

static void on_mysql_res_error(MYSQL_RES *p)
{
    /* MYSQL_RES contains a pointer to the connection.  This is null if it
     * doesn't need the connection (eg store versus use).
     */
    if (p->handle)
        on_mysql_error(p->handle);
}

function mysql_MySql_new_impl()
    body {
       MYSQL *res;
       res = mysql_init(NULL);
       if (res == NULL) {
           LitWhy("mysql_init returned null");
           fail;
       }
       return C_integer (word)res;
   }
end

function mysql_MySql_close(self)
   body {
      GetSelfMySql();
      mysql_close(self_mysql);
      *self_mysql_dptr = nulldesc;
      return self;
   } 
end

function mysql_MySql_set_server_option(self, opt) 
   if !cnv:C_integer(opt) then
       runerr(101, opt)
   body {
      enum enum_mysql_set_option option;
      GetSelfMySql();
      option = (enum enum_mysql_set_option)opt;
      if (mysql_set_server_option(self_mysql, option)) {
          on_mysql_error(self_mysql);
          fail;
      }
      return self;
   }
end

function mysql_MySql_options(self, option, arg)
   if !cnv:C_integer(option) then
      runerr(101, option)

   body {
      tended char *c_arg;
      unsigned int int_arg;
      GetSelfMySql();

      switch (option) {
          /*
           * These take a single mandatory int as an arg.
           */
          case MYSQL_OPT_CONNECT_TIMEOUT: {
              word w;
              if (!cnv:C_integer(arg, w))
                  runerr(101, arg);
              int_arg = (unsigned int)w;
              c_arg = (char*)&int_arg;
              break;
          }

          /*
           * These take a single optional int as an arg.
           */
          case MYSQL_OPT_LOCAL_INFILE: {
              if (is:null(arg))
                  c_arg = NULL;
              else {
                  word w;
                  if (!cnv:C_integer(arg, w))
                      runerr(101, arg);
                  int_arg = (unsigned int)w;
                  c_arg = (char*)&int_arg;
              }
              break;
          }

          /*
           * These take a single mandatory char* as an arg.
           */
          case MYSQL_INIT_COMMAND:
          case MYSQL_READ_DEFAULT_FILE:
          case MYSQL_READ_DEFAULT_GROUP: {
              if (!cnv:C_string(arg, c_arg))
                  runerr(103, arg);
              break;
          }

          case MYSQL_OPT_COMPRESS:
          case MYSQL_OPT_NAMED_PIPE: {
              c_arg = NULL;
              break;
          }

          default: {
              LitWhy("Bad option number");
              fail;
          }
      }
      if (mysql_options(self_mysql, (enum mysql_option)option, c_arg)) {
          on_mysql_error(self_mysql);
          fail;
      }
      return self;
   }
end

function mysql_MySql_ping(self)
   body {
      GetSelfMySql();
      if (mysql_ping(self_mysql)) {
          on_mysql_error(self_mysql);
          fail;
      }
      return self;
   }
end

function mysql_MySql_esc(self, str)
   if !cnv:string(str) then
       runerr(103, str)
   body {
      char *to;
      tended struct descrip result;
      unsigned long to_len;
      GetSelfMySql();
      to = safe_malloc(2 * StrLen(str) + 1);
      to_len = mysql_real_escape_string(self_mysql, to, StrLoc(str), StrLen(str));
      bytes2string(to, to_len, &result);
      free(to);
      return result;
   }
end

function mysql_MySql_select_db(self, db)
   if !cnv:C_string(db) then
       runerr(103, db)
   body {
      GetSelfMySql();
      if (mysql_select_db(self_mysql, db)) {
          on_mysql_error(self_mysql);
          fail;
      }
      return self;
   }
end

function mysql_MySql_shutdown(self)
   body {
      GetSelfMySql();

      if (mysql_shutdown(self_mysql, SHUTDOWN_DEFAULT))
      {
          on_mysql_error(self_mysql);
          fail;
      }
      return self;
   }
end

function mysql_MySql_change_user(self, user, passwd, db)
   body {
      tended char *c_user;
      tended char *c_passwd;
      tended char *c_db;
      GetSelfMySql();

      if (is:null(user))
          c_user = NULL;
      else if (!cnv:C_string(user, c_user))
          runerr(103, user);

      if (is:null(passwd))
          c_passwd = NULL;
      else if (!cnv:C_string(passwd, c_passwd))
          runerr(103, passwd);

      if (is:null(db))
          c_db = NULL;
      else if (!cnv:C_string(db, c_db))
          runerr(103, db);

      if (mysql_change_user(self_mysql, c_user, c_passwd, c_db)) {
          on_mysql_error(self_mysql);
          fail;
      }
      return self;
   }
end

function mysql_MySql_get_character_set_name(self)
   body {
      tended struct descrip result;
      GetSelfMySql();
      cstr2string((char*)mysql_character_set_name(self_mysql), &result);
      return result;
   }
end

function mysql_MySql_dump_debug_info(self)
   body {
      GetSelfMySql();
      if (mysql_dump_debug_info(self_mysql)) {
          on_mysql_error(self_mysql);
          fail;
      }
      return self;
   }
end

function mysql_MySql_get_client_info()
   body {
    tended struct descrip result;
    cstr2string((char*)mysql_get_client_info(), &result);
    return result;
   }
end

function mysql_MySql_get_client_version()
   body {
      return C_integer mysql_get_client_version();
   }
end

function mysql_MySql_get_host_info(self)
   body {
      tended struct descrip result;
      GetSelfMySql();
      cstr2string((char*)mysql_get_host_info(self_mysql), &result);
      return result;
   }
end

function mysql_MySql_get_sqlstate(self)
   body {
      tended struct descrip result;
      GetSelfMySql();
      cstr2string((char*)mysql_sqlstate(self_mysql), &result);
      return result;
   }
end

function mysql_MySql_get_proto_info(self)
   body {
      GetSelfMySql();
      return C_integer mysql_get_proto_info(self_mysql);
   }
end

function mysql_MySql_get_server_info(self)
   body {
      tended struct descrip result;
      GetSelfMySql();
      cstr2string((char*)mysql_get_server_info(self_mysql), &result);
      return result;
   }
end

function mysql_MySql_get_server_version(self)
   body {
      GetSelfMySql();
      return C_integer mysql_get_server_version(self_mysql);
   }
end

function mysql_MySql_get_info(self)
   body {
      tended struct descrip result;
      GetSelfMySql();
      cstr2string((char*)mysql_info(self_mysql), &result);
      return result;
   }
end

function mysql_MySql_get_stat(self)
   body {
      char *s;
      tended struct descrip result;
      GetSelfMySql();
      s = (char*)mysql_stat(self_mysql);
      if (s == NULL) {
          on_mysql_error(self_mysql);
          fail;
      }
      cstr2string(s, &result);
      return result;
   }
end

function mysql_MySql_commit(self)
   body {
      GetSelfMySql();
      if (mysql_commit(self_mysql)) {
          on_mysql_error(self_mysql);
          fail;
      }
      return self;
   }
end

function mysql_MySql_rollback(self)
   body {
      GetSelfMySql();
      if (mysql_rollback(self_mysql)) {
          on_mysql_error(self_mysql);
          fail;
      }
      return self;
   }
end

function mysql_MySql_set_autocommit(self, flag)
   body {
      int t;
      GetSelfMySql();
      if (!is_flag(&flag))
          runerr(171, flag);
      if (is:null(flag))
          t = 0;
      else
          t = 1;
      if (mysql_autocommit(self_mysql, t)) {
          on_mysql_error(self_mysql);
          fail;
      }
      return self;
    }
end

function mysql_MySql_more_results(self)
   body {
      GetSelfMySql();
      if (mysql_more_results(self_mysql))
          return self;
      else {
          on_mysql_error(self_mysql);
          fail;
      }
   }
end

function mysql_MySql_next_result(self)
   body {
      GetSelfMySql();
      if (mysql_next_result(self_mysql)) {
          on_mysql_error(self_mysql);
          fail;
      }
      return self;
    }
end

function mysql_MySql_get_affected_rows(self)
   body {
      GetSelfMySql();
      return C_integer mysql_affected_rows(self_mysql);
   }
end

function mysql_MySql_connect(self, host, user, passwd, db, 
                                  port, unix_socket, client_flag)
   body {
      tended char *c_host;
      tended char *c_user;
      tended char *c_passwd;
      tended char *c_db;
      unsigned int c_port;
      tended char *c_unix_socket;
      unsigned int c_client_flag;
      GetSelfMySql();

      if (is:null(host))
          c_host = NULL;
      else if (!cnv:C_string(host, c_host))
          runerr(103, host);

      if (is:null(user))
          c_user = NULL;
      else if (!cnv:C_string(user, c_user))
          runerr(103, user);

      if (is:null(passwd))
          c_passwd = NULL;
      else if (!cnv:C_string(passwd, c_passwd))
          runerr(103, passwd);

      if (is:null(db))
          c_db = NULL;
      else if (!cnv:C_string(db, c_db))
          runerr(103, db);

      if (is:null(port))
          c_port = 0;
      else {
          word w;
          if (!cnv:C_integer(port, w))
              runerr(101, port);
          c_port = (unsigned int)w;
      }

      if (is:null(unix_socket))
          c_unix_socket = NULL;
      else if (!cnv:C_string(unix_socket, c_unix_socket))
          runerr(103, unix_socket);

      if (is:null(client_flag))
          c_client_flag = 0;
      else {
          word w;
          if (!cnv:C_integer(client_flag, w))
              runerr(101, client_flag);
          c_client_flag = (unsigned int)w;
      }

      if (!mysql_real_connect(self_mysql, c_host, c_user, c_passwd, 
                              c_db, c_port, c_unix_socket, c_client_flag)) {
          on_mysql_error(self_mysql);
          fail;
      }

      return self;
   }
end

function mysql_MySql_ssl_set(self, key, cert, ca, capath, cipher)
   body {
      tended char *c_key;
      tended char *c_cert;
      tended char *c_ca;
      tended char *c_capath;
      tended char *c_cipher;
      GetSelfMySql();

      if (is:null(key))
          c_key = NULL;
      else if (!cnv:C_string(key, c_key))
          runerr(103, key);

      if (is:null(cert))
          c_cert = NULL;
      else if (!cnv:C_string(cert, c_cert))
          runerr(103, cert);

      if (is:null(ca))
          c_ca = NULL;
      else if (!cnv:C_string(ca, c_ca))
          runerr(103, ca);

      if (is:null(capath))
          c_capath = NULL;
      else if (!cnv:C_string(capath, c_capath))
          runerr(103, capath);

      if (is:null(cipher))
          c_cipher = NULL;
      else if (!cnv:C_string(cipher, c_cipher))
          runerr(103, cipher);

      mysql_ssl_set(self_mysql, c_key, c_cert, c_ca, c_capath, c_cipher);
      return self;
   }
end

function mysql_MySql_get_error(self)
   body {
      tended struct descrip result;
      GetSelfMySql();
      cstr2string((char*)mysql_error(self_mysql), &result);
      return result;
   }
end

function mysql_MySql_get_errno(self)
   body {
      GetSelfMySql();
      return C_integer mysql_errno(self_mysql);
   }
end

function mysql_MySql_get_thread_id(self)
   body {
      GetSelfMySql();
      return C_integer mysql_thread_id(self_mysql);
   }
end

function mysql_MySql_get_warning_count(self)
   body {
      GetSelfMySql();
      return C_integer mysql_warning_count(self_mysql);
   }
end

function mysql_MySql_query(self, q)
   if !cnv:string(q) then
       runerr(103, q)
   body {
      GetSelfMySql();
      if (mysql_real_query(self_mysql, StrLoc(q), StrLen(q))) {
          on_mysql_error(self_mysql);
          fail;
      }
      return self;
   }
end

function mysql_MySql_get_field_count(self)
   body {
      GetSelfMySql();
      return C_integer mysql_field_count(self_mysql);
   }
end

function mysql_MySql_get_insert_id(self)
   body {
      GetSelfMySql();
      return C_integer mysql_insert_id(self_mysql);
   }
end

function mysql_MySql_kill(self, pid)
   if !cnv:C_integer(pid) then
       runerr(101, pid)
   body {
      GetSelfMySql();
      if (mysql_kill(self_mysql, pid)) {
          on_mysql_error(self_mysql);
          fail;
      }
      return self;
   }
end

function mysql_MySql_list_dbs_impl(self, wild)
   body {
      MYSQL_RES *res;
      tended char *c_wild;
      GetSelfMySql();

      if (is:null(wild))
          c_wild = NULL;
      else if (!cnv:C_string(wild, c_wild))
          runerr(103, wild);

      res = mysql_list_dbs(self_mysql, c_wild);
      if (!res) {
          on_mysql_error(self_mysql);
          fail;
      }
      return C_integer (word)res;
   }
end

function mysql_MySql_list_fields_impl(self, table, wild)
   body {
      MYSQL_RES *res;
      tended char *c_table;
      tended char *c_wild;
      GetSelfMySql();

      if (!cnv:C_string(table, c_table))
          runerr(103, table);

      if (is:null(wild))
          c_wild = NULL;
      else if (!cnv:C_string(wild, c_wild))
          runerr(103, wild);

      res = mysql_list_fields(self_mysql, c_table, c_wild);
      if (!res) {
          on_mysql_error(self_mysql);
          fail;
      }
      return C_integer (word)res;
   }
end

function mysql_MySql_list_processes_impl(self)
   body {
      MYSQL_RES *res;
      GetSelfMySql();
      res = mysql_list_processes(self_mysql);
      if (!res) {
          on_mysql_error(self_mysql);
          fail;
      }
      return C_integer (word)res;
   }
end

function mysql_MySql_list_tables_impl(self, wild)
   body {
      MYSQL_RES *res;
      tended char *c_wild;
      GetSelfMySql();

      if (is:null(wild))
          c_wild = NULL;
      else if (!cnv:C_string(wild, c_wild))
          runerr(103, wild);

      res = mysql_list_tables(self_mysql, c_wild);
      if (!res) {
          on_mysql_error(self_mysql);
          fail;
      }
      return C_integer (word)res;
   }
end

function mysql_MySql_use_result_impl(self)
   body {
      MYSQL_RES *res;
      GetSelfMySql();

      res = mysql_use_result(self_mysql);
      if (!res) {
          on_mysql_error(self_mysql);
          fail;
      }
      return C_integer (word)res;
   }
end

function mysql_MySql_store_result_impl(self)
   body {
      MYSQL_RES *res;
      GetSelfMySql();

      res = mysql_store_result(self_mysql);
      if (!res) {
          on_mysql_error(self_mysql);
          fail;
      }
      return C_integer (word)res;
   }
end

function mysql_MySqlRes_get_num_fields(self)
   body {
       GetSelfMySqlRes();
       return C_integer mysql_num_fields(self_mysql_res);
   }
end

function mysql_MySqlRes_fetch_field_impl(self)
   body {
       tended struct descrip result;
       MYSQL_FIELD *field;
       GetSelfMySqlRes();
       field = mysql_fetch_field(self_mysql_res);
       if (!field) {
           LitWhy("No more fields");
           fail;
       }
       field_to_list(field, &result);
       return result;
   }
end

/* def is a reserved word in rtl */
#passthru #define _DEF def

static void field_to_list(MYSQL_FIELD *field, dptr result) {
   tended struct descrip tmp;

   create_list(10, result);
   cstr2string(field->name, &tmp);
   list_put(result, &tmp);
   cstr2string(field->table, &tmp);
   list_put(result, &tmp);
   cstr2string(field->org_table, &tmp);
   list_put(result, &tmp);
   cstr2string(field->db, &tmp);
   list_put(result, &tmp);
   cstr2string(field->_DEF, &tmp);
   list_put(result, &tmp);
   MakeInt(field->length, &tmp);
   list_put(result, &tmp);
   MakeInt(field->max_length, &tmp);
   list_put(result, &tmp);
   MakeInt(field->flags, &tmp);
   list_put(result, &tmp);
   MakeInt(field->decimals, &tmp);
   list_put(result, &tmp);
   MakeInt(field->type, &tmp);
   list_put(result, &tmp);
}

function mysql_MySqlRes_fetch_field_direct_impl(self, fieldnr)
   if !cnv:C_integer(fieldnr) then
       runerr(101, fieldnr)
   body {
       tended struct descrip result;
       MYSQL_FIELD *field;
       GetSelfMySqlRes();
       field = mysql_fetch_field_direct(self_mysql_res, fieldnr);
       if (!field) {
           LitWhy("No more fields");
           fail;
       }
       field_to_list(field, &result);
       return result;
   }
end

function mysql_MySqlRes_fetch_fields_impl(self)
   body {
       tended struct descrip result;
       MYSQL_FIELD *fields;
       int i, n;
       GetSelfMySqlRes();

       fields = mysql_fetch_fields(self_mysql_res);
       if (!fields) {
           LitWhy("No more fields");
           fail;
       }

       n = mysql_num_fields(self_mysql_res);
       create_list(n, &result);
       for (i = 0; i < n; ++i) {
           tended struct descrip tmp;
           field_to_list(&fields[i], &tmp);
           list_put(&result, &tmp);
       }
       return result;
   }
end

function mysql_MySqlRes_field_seek(self, offset)
   if !cnv:C_integer(offset) then
       runerr(101, offset)
   body {
       GetSelfMySqlRes();
       return C_integer mysql_field_seek(self_mysql_res, (MYSQL_FIELD_OFFSET)offset);
   }
end

function mysql_MySqlRes_field_tell(self)
   body {
       GetSelfMySqlRes();
       return C_integer mysql_field_tell(self_mysql_res);
   }
end

function mysql_MySqlRes_fetch_lengths(self)
   body {
       int i, n;
       tended struct descrip result;
       unsigned long *lengths;
       GetSelfMySqlRes();
       lengths = mysql_fetch_lengths(self_mysql_res);
       if (!lengths) {
           LitWhy("mysql_fetch_lengths returned null");
           fail;
       }
       n = mysql_num_fields(self_mysql_res);
       create_list(n, &result);
       for (i = 0; i < n; ++i) {
           struct descrip tmp;
           MakeInt(lengths[i], &tmp);
           list_put(&result, &tmp);
       }
       return result;
   }
end

function mysql_MySqlRes_fetch_row(self)
   body {
       int i, n;
       unsigned long *lengths;
       tended struct descrip result;
       MYSQL_ROW row;
       GetSelfMySqlRes();
       row = mysql_fetch_row(self_mysql_res);
       if (!row) {
           on_mysql_res_error(self_mysql_res);
           fail;
       }
       lengths = mysql_fetch_lengths(self_mysql_res);
       if (!lengths) {
           LitWhy("mysql_fetch_lengths returned null");
           fail;
       }

       n = mysql_num_fields(self_mysql_res);
       create_list(n, &result);
       for (i = 0; i < n; ++i) {
           if (row[i]) {
               tended struct descrip tmp;
               bytes2string(row[i], lengths[i], &tmp);
               list_put(&result, &tmp);
           } else
               list_put(&result, &nulldesc);
       }
       return result;
   }
end

function mysql_MySqlRes_row_seek(self, offset)
   if !cnv:C_integer(offset) then
       runerr(101, offset)
   body {
       GetSelfMySqlRes();
       return C_integer (word)mysql_row_seek(self_mysql_res, (MYSQL_ROW_OFFSET)offset);
   }
end

function mysql_MySqlRes_row_tell(self)
   body {
       GetSelfMySqlRes();
       return C_integer (word)mysql_row_tell(self_mysql_res);
   }
end

function mysql_MySqlRes_data_seek(self, offset)
   if !cnv:C_integer(offset) then
       runerr(101, offset)
   body {
       GetSelfMySqlRes();
       mysql_data_seek(self_mysql_res, (my_ulonglong)offset);
       return self;
   }
end

function mysql_MySqlRes_get_num_rows(self)
   body {
       GetSelfMySqlRes();
       return C_integer mysql_num_rows(self_mysql_res);
   }
end

function mysql_MySqlRes_close(self)
   body {
       GetSelfMySqlRes();
       mysql_free_result(self_mysql_res);
       *self_mysql_res_dptr = nulldesc;
       return self;
   }
end
