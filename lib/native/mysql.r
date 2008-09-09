#passthru #undef column
#passthru #include "mysql.h"

static struct descrip field_to_list(MYSQL_FIELD *field);

static struct sdescrip ptrf = {3, "ptr"};

#begdef MySqlSelfParam(m)
MYSQL *m;
dptr m##_dptr;
static struct inline_field_cache m##_ic;
m##_dptr = c_get_instance_data(&self, (dptr)&ptrf, &m##_ic);
if (!m##_dptr)
    runerr(207,*(dptr)&ptrf);
(m) = (MYSQL*)IntVal(*m##_dptr);
if (!(m))
    runerr(205, self);
#enddef

#begdef MySqlResSelfParam(m)
MYSQL_RES *m;
dptr m##_dptr;
static struct inline_field_cache m##_ic;
m##_dptr = c_get_instance_data(&self, (dptr)&ptrf, &m##_ic);
if (!m##_dptr)
    runerr(207,*(dptr)&ptrf);
(m) = (MYSQL_RES*)IntVal(*m##_dptr);
if (!(m))
    runerr(205, self);
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

function{0,1} mysql_MySql_new_impl()
    body {
       MYSQL *res;
       res = mysql_init(NULL);
       if (res == NULL) {
           why("mysql_init returned null");
           fail;
       }
       return C_integer (long int)res;
   }
end

function{1} mysql_MySql_close(self)
   body {
      MySqlSelfParam(mysql);
      mysql_close(mysql);
      *mysql_dptr = zerodesc;
      return nulldesc;
   } 
end

function{0,1} mysql_MySql_set_server_option(self, opt) 
   if !cnv:C_integer(opt) then
       runerr(101, opt)
   body {
      enum enum_mysql_set_option option;
      MySqlSelfParam(mysql);
      option = (enum enum_mysql_set_option)opt;
      if (mysql_set_server_option(mysql, option)) {
          on_mysql_error(mysql);
          fail;
      }
      return nulldesc;
   }
end

function{0,1} mysql_MySql_options(self, option, arg)
   if !cnv:C_integer(option) then
      runerr(101, option)

   body {
      tended char *c_arg;
      unsigned int int_arg;
      MySqlSelfParam(mysql);

      switch (option) {
          /*
           * These take a single mandatory int as an arg.
           */
          case MYSQL_OPT_CONNECT_TIMEOUT: {
              if (!cnv:C_integer(arg, int_arg))
                  runerr(101, arg);
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
                  if (!cnv:C_integer(arg, int_arg))
                      runerr(101, arg);
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
              why("Bad option number");
              fail;
          }
      }
      if (mysql_options(mysql, (enum mysql_option)option, c_arg)) {
          on_mysql_error(mysql);
          fail;
      }
      return nulldesc;
   }
end

function{0,1} mysql_MySql_ping(self)
   body {
      MySqlSelfParam(mysql);
      if (mysql_ping(mysql)) {
          on_mysql_error(mysql);
          fail;
      }
      return nulldesc;
   }
end

function{1} mysql_MySql_esc(self, str)
   if !cnv:string(str) then
       runerr(103, str)
   body {
      char *to;
      unsigned long to_len;
      MySqlSelfParam(mysql);
      MemProtect(to = malloc(2 * StrLen(str) + 1));
      to_len = mysql_real_escape_string(mysql, to, StrLoc(str), StrLen(str));
      result = bytes2string(to, to_len);
      free(to);
      return result;
   }
end

function{0,1} mysql_MySql_select_db(self, db)
   if !cnv:C_string(db) then
       runerr(103, db)
   body {
      MySqlSelfParam(mysql);
      if (mysql_select_db(mysql, db)) {
          on_mysql_error(mysql);
          fail;
      }
      return nulldesc;
   }
end

function{0,1} mysql_MySql_shutdown(self)
   body {
      MySqlSelfParam(mysql);
      if (mysql_shutdown(mysql)) {
          on_mysql_error(mysql);
          fail;
      }
      return nulldesc;
   }
end

function{0,1} mysql_MySql_change_user(self, user, passwd, db)
   body {
      tended char *c_user;
      tended char *c_passwd;
      tended char *c_db;
      MySqlSelfParam(mysql);

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

      if (mysql_change_user(mysql, c_user, c_passwd, c_db)) {
          on_mysql_error(mysql);
          fail;
      }
      return nulldesc;
   }
end

function{1} mysql_MySql_get_character_set_name(self)
   body {
      MySqlSelfParam(mysql);
      return cstr2string((char*)mysql_character_set_name(mysql));
   }
end

function{0,1} mysql_MySql_dump_debug_info(self)
   body {
      MySqlSelfParam(mysql);
      if (mysql_dump_debug_info(mysql)) {
          on_mysql_error(mysql);
          fail;
      }
      return nulldesc;
   }
end

function{1} mysql_MySql_get_client_info()
   body {
      return cstr2string((char*)mysql_get_client_info());
   }
end

function{1} mysql_MySql_get_client_version()
   body {
      return C_integer mysql_get_client_version();
   }
end

function{1} mysql_MySql_get_host_info(self)
   body {
      MySqlSelfParam(mysql);
      return cstr2string((char*)mysql_get_host_info(mysql));
   }
end

function{1} mysql_MySql_get_sqlstate(self)
   body {
      MySqlSelfParam(mysql);
      return cstr2string((char*)mysql_sqlstate(mysql));
   }
end

function{1} mysql_MySql_get_proto_info(self)
   body {
      MySqlSelfParam(mysql);
      return C_integer mysql_get_proto_info(mysql);
   }
end

function{1} mysql_MySql_get_server_info(self)
   body {
      MySqlSelfParam(mysql);
      return cstr2string((char*)mysql_get_server_info(mysql));
   }
end

function{1} mysql_MySql_get_server_version(self)
   body {
      MySqlSelfParam(mysql);
      return C_integer mysql_get_server_version(mysql);
   }
end

function{1} mysql_MySql_get_info(self)
   body {
      MySqlSelfParam(mysql);
      return cstr2string((char*)mysql_info(mysql));
   }
end

function{0,1} mysql_MySql_get_stat(self)
   body {
      char *s;
      MySqlSelfParam(mysql);
      s = (char*)mysql_stat(mysql);
      if (s == NULL) {
          on_mysql_error(mysql);
          fail;
      }
      return cstr2string(s);
   }
end

function{0,1} mysql_MySql_commit(self)
   body {
      MySqlSelfParam(mysql);
      if (mysql_commit(mysql)) {
          on_mysql_error(mysql);
          fail;
      }
      return nulldesc;
   }
end

function{0,1} mysql_MySql_rollback(self)
   body {
      MySqlSelfParam(mysql);
      if (mysql_rollback(mysql)) {
          on_mysql_error(mysql);
          fail;
      }
      return nulldesc;
   }
end

function{0,1} mysql_MySql_set_autocommit_impl(self, mode)
   if !cnv:C_integer(mode) then
       runerr(101, mode)
   body {
      MySqlSelfParam(mysql);
      if (mysql_autocommit(mysql, (my_bool)mode)) {
          on_mysql_error(mysql);
          fail;
      }
      return nulldesc;
    }
end

function{0,1} mysql_MySql_more_results(self)
   body {
      MySqlSelfParam(mysql);
      if (mysql_more_results(mysql))
          return nulldesc;
      else {
          on_mysql_error(mysql);
          fail;
      }
   }
end

function{0,1} mysql_MySql_next_result(self)
   body {
      MySqlSelfParam(mysql);
      if (mysql_next_result(mysql)) {
          on_mysql_error(mysql);
          fail;
      }
      return nulldesc;
    }
end

function{1} mysql_MySql_get_affected_rows(self)
   body {
      MySqlSelfParam(mysql);
      return C_integer mysql_affected_rows(mysql);
   }
end

function{0,1} mysql_MySql_connect(self, host, user, passwd, db, 
                                  port, unix_socket, client_flag)
   body {
      tended char *c_host;
      tended char *c_user;
      tended char *c_passwd;
      tended char *c_db;
      unsigned int c_port;
      tended char *c_unix_socket;
      unsigned int c_client_flag;
      MySqlSelfParam(mysql);

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
      else if (!cnv:C_integer(port, c_port))
          runerr(101, port);

      if (is:null(unix_socket))
          c_unix_socket = NULL;
      else if (!cnv:C_string(unix_socket, c_unix_socket))
          runerr(103, unix_socket);

      if (is:null(client_flag))
          c_client_flag = 0;
      else if (!cnv:C_integer(client_flag, c_client_flag))
          runerr(101, client_flag);

      if (!mysql_real_connect(mysql, c_host, c_user, c_passwd, 
                              c_db, c_port, c_unix_socket, c_client_flag)) {
          on_mysql_error(mysql);
          fail;
      }

      return nulldesc;
   }
end

function{0,1} mysql_MySql_ssl_set(self, key, cert, ca, capath, cipher)
   body {
      tended char *c_key;
      tended char *c_cert;
      tended char *c_ca;
      tended char *c_capath;
      tended char *c_cipher;
      MySqlSelfParam(mysql);

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

      mysql_ssl_set(mysql, c_key, c_cert, c_ca, c_capath, c_cipher);
      return nulldesc;
   }
end

function{1} mysql_MySql_get_error(self)
   body {
      MySqlSelfParam(mysql);
      return cstr2string((char*)mysql_error(mysql));
   }
end

function{1} mysql_MySql_get_errno(self)
   body {
      MySqlSelfParam(mysql);
      return C_integer mysql_errno(mysql);
   }
end

function{1} mysql_MySql_get_thread_id(self)
   body {
      MySqlSelfParam(mysql);
      return C_integer mysql_thread_id(mysql);
   }
end

function{1} mysql_MySql_get_warning_count(self)
   body {
      MySqlSelfParam(mysql);
      return C_integer mysql_warning_count(mysql);
   }
end

function{0,1} mysql_MySql_query(self, q)
   if !cnv:string(q) then
       runerr(103, q)
   body {
      MySqlSelfParam(mysql);
      if (mysql_real_query(mysql, StrLoc(q), StrLen(q))) {
          on_mysql_error(mysql);
          fail;
      }
      return nulldesc;
   }
end

function{1} mysql_MySql_get_field_count(self)
   body {
      MySqlSelfParam(mysql);
      return C_integer mysql_field_count(mysql);
   }
end

function{1} mysql_MySql_get_insert_id(self)
   body {
      MySqlSelfParam(mysql);
      return C_integer mysql_insert_id(mysql);
   }
end

function{0,1} mysql_MySql_kill(self, pid)
   if !cnv:C_integer(pid) then
       runerr(101, pid)
   body {
      MySqlSelfParam(mysql);
      if (mysql_kill(mysql, pid)) {
          on_mysql_error(mysql);
          fail;
      }
      return nulldesc;
   }
end

function{0,1} mysql_MySql_list_dbs_impl(self, wild)
   body {
      MYSQL_RES *res;
      tended char *c_wild;
      MySqlSelfParam(mysql);

      if (is:null(wild))
          c_wild = NULL;
      else if (!cnv:C_string(wild, c_wild))
          runerr(103, wild);

      res = mysql_list_dbs(mysql, c_wild);
      if (!res) {
          on_mysql_error(mysql);
          fail;
      }
      return C_integer((long int)res);
   }
end

function{0,1} mysql_MySql_list_fields_impl(self, table, wild)
   body {
      MYSQL_RES *res;
      tended char *c_table;
      tended char *c_wild;
      MySqlSelfParam(mysql);

      if (!cnv:C_string(table, c_table))
          runerr(103, table);

      if (is:null(wild))
          c_wild = NULL;
      else if (!cnv:C_string(wild, c_wild))
          runerr(103, wild);

      res = mysql_list_fields(mysql, c_table, c_wild);
      if (!res) {
          on_mysql_error(mysql);
          fail;
      }
      return C_integer((long int)res);
   }
end

function{0,1} mysql_MySql_list_processes_impl(self)
   body {
      MYSQL_RES *res;
      MySqlSelfParam(mysql);
      res = mysql_list_processes(mysql);
      if (!res) {
          on_mysql_error(mysql);
          fail;
      }
      return C_integer((long int)res);
   }
end

function{0,1} mysql_MySql_list_tables_impl(self, wild)
   body {
      MYSQL_RES *res;
      tended char *c_wild;
      MySqlSelfParam(mysql);

      if (is:null(wild))
          c_wild = NULL;
      else if (!cnv:C_string(wild, c_wild))
          runerr(103, wild);

      res = mysql_list_tables(mysql, c_wild);
      if (!res) {
          on_mysql_error(mysql);
          fail;
      }
      return C_integer((long int)res);
   }
end

function{0,1} mysql_MySql_use_result_impl(self)
   body {
      MYSQL_RES *res;
      MySqlSelfParam(mysql);

      res = mysql_use_result(mysql);
      if (!res) {
          on_mysql_error(mysql);
          fail;
      }
      return C_integer((long int)res);
   }
end

function{0,1} mysql_MySql_store_result_impl(self)
   body {
      MYSQL_RES *res;
      MySqlSelfParam(mysql);

      res = mysql_store_result(mysql);
      if (!res) {
          on_mysql_error(mysql);
          fail;
      }
      return C_integer((long int)res);
   }
end

function{1} mysql_MySqlRes_get_num_fields(self)
   body {
       MySqlResSelfParam(mysql_res);
       return C_integer mysql_num_fields(mysql_res);
   }
end

function{0,1} mysql_MySqlRes_fetch_field_impl(self)
   body {
       MYSQL_FIELD *field;
       MySqlResSelfParam(mysql_res);
       field = mysql_fetch_field(mysql_res);
       if (!field) {
           why("No more fields");
           fail;
       }
       return field_to_list(field);
   }
end

/* def is a reserved word in rtl */
#passthru #define _DEF def

static struct descrip field_to_list(MYSQL_FIELD *field) {
   tended struct descrip tmp, res;

   res = create_list(10);
   tmp = cstr2string(field->name);
   c_put(&res, &tmp);
   tmp = cstr2string(field->table);
   c_put(&res, &tmp);
   tmp = cstr2string(field->org_table);
   c_put(&res, &tmp);
   tmp = cstr2string(field->db);
   c_put(&res, &tmp);
   tmp = cstr2string(field->_DEF);
   c_put(&res, &tmp);
   MakeInt(field->length, &tmp);
   c_put(&res, &tmp);
   MakeInt(field->max_length, &tmp);
   c_put(&res, &tmp);
   MakeInt(field->flags, &tmp);
   c_put(&res, &tmp);
   MakeInt(field->decimals, &tmp);
   c_put(&res, &tmp);
   MakeInt(field->type, &tmp);
   c_put(&res, &tmp);

   return res;
}

function{0,1} mysql_MySqlRes_fetch_field_direct_impl(self, fieldnr)
   if !cnv:C_integer(fieldnr) then
       runerr(101, fieldnr)
   body {
       MYSQL_FIELD *field;
       MySqlResSelfParam(mysql_res);
       field = mysql_fetch_field_direct(mysql_res, fieldnr);
       if (!field) {
           why("No more fields");
           fail;
       }
       return field_to_list(field);
   }
end

function{0,1} mysql_MySqlRes_fetch_fields_impl(self)
   body {
       MYSQL_FIELD *fields;
       int i, n;
       MySqlResSelfParam(mysql_res);

       fields = mysql_fetch_fields(mysql_res);
       if (!fields) {
           why("No more fields");
           fail;
       }

       n = mysql_num_fields(mysql_res);
       result = create_list(n);
       for (i = 0; i < n; ++i) {
           tended struct descrip tmp = field_to_list(&fields[i]);
           c_put(&result, &tmp);
       }
       return result;
   }
end

function{1} mysql_MySqlRes_field_seek(self, offset)
   if !cnv:C_integer(offset) then
       runerr(101, offset)
   body {
       MySqlResSelfParam(mysql_res);
       return C_integer mysql_field_seek(mysql_res, (MYSQL_FIELD_OFFSET)offset);
   }
end

function{1} mysql_MySqlRes_field_tell(self)
   body {
       MySqlResSelfParam(mysql_res);
       return C_integer mysql_field_tell(mysql_res);
   }
end

function{0,1} mysql_MySqlRes_fetch_lengths(self)
   body {
       int i, n;
       unsigned long *lengths;
       MySqlResSelfParam(mysql_res);
       lengths = mysql_fetch_lengths(mysql_res);
       if (!lengths) {
           why("mysql_fetch_lengths returned null");
           fail;
       }
       n = mysql_num_fields(mysql_res);
       result = create_list(n);
       for (i = 0; i < n; ++i) {
           struct descrip tmp;
           MakeInt(lengths[i], &tmp);
           c_put(&result, &tmp);
       }
       return result;
   }
end

function{0,1} mysql_MySqlRes_fetch_row(self)
   body {
       int i, n;
       unsigned long *lengths;
       MYSQL_ROW row;
       MySqlResSelfParam(mysql_res);
       row = mysql_fetch_row(mysql_res);
       if (!row) {
           on_mysql_res_error(mysql_res);
           fail;
       }
       lengths = mysql_fetch_lengths(mysql_res);
       if (!lengths) {
           why("mysql_fetch_lengths returned null");
           fail;
       }

       n = mysql_num_fields(mysql_res);
       result = create_list(n);
       for (i = 0; i < n; ++i) {
           tended struct descrip tmp = bytes2string(row[i], lengths[i]);
           c_put(&result, &tmp);
       }
       return result;
   }
end

function{1} mysql_MySqlRes_row_seek(self, offset)
   if !cnv:C_integer(offset) then
       runerr(101, offset)
   body {
       MySqlResSelfParam(mysql_res);
       return C_integer((long int)mysql_row_seek(mysql_res, (MYSQL_ROW_OFFSET)offset));
   }
end

function{1} mysql_MySqlRes_row_tell(self)
   body {
       MySqlResSelfParam(mysql_res);
       return C_integer((long int)mysql_row_tell(mysql_res));
   }
end

function{1} mysql_MySqlRes_data_seek(self, offset)
   if !cnv:C_integer(offset) then
       runerr(101, offset)
   body {
       MySqlResSelfParam(mysql_res);
       mysql_data_seek(mysql_res, (my_ulonglong)offset);
       return nulldesc;
   }
end

function{1} mysql_MySqlRes_get_num_rows(self)
   body {
       MySqlResSelfParam(mysql_res);
       return C_integer mysql_num_rows(mysql_res);
   }
end

function{1} mysql_MySqlRes_free(self)
   body {
       MySqlResSelfParam(mysql_res);
       mysql_free_result(mysql_res);
       *mysql_res_dptr = zerodesc;
       return nulldesc;
   }
end
