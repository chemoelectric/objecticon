#passthru #undef column
#passthru #include "mysql.h"

static struct descrip field_to_list(MYSQL_FIELD *field);

function{0,1} unimysql_init()
    body {
       MYSQL *res;
       res = mysql_init(NULL);
       if (res == NULL)
          fail;
       return C_integer (long int)res;
   }
end

function{1} unimysql_close(id) 
   if !cnv:C_integer(id) then
       runerr(101, id)
   body {
      MYSQL *mysql;
      mysql = (MYSQL*)id;
      mysql_close(mysql);
      return nulldesc;
   } 
end

function{0,1} unimysql_set_server_option(id, opt) 
   if !cnv:C_integer(id) then
       runerr(101, id)
   if !cnv:C_integer(opt) then
       runerr(101, opt)
   body {
      MYSQL *mysql;
      enum enum_mysql_set_option option;
      mysql = (MYSQL*)id;
      option = (enum enum_mysql_set_option)opt;
      if (mysql_set_server_option(mysql, option))
          fail;
      return nulldesc;
   }
end

function{0,1} unimysql_options(argv[argc])
   body {
      MYSQL *mysql;
      enum mysql_option option;
      char *arg;
      unsigned int int_arg;

      if (argc < 1)
          runerr(101);
      if (!cnv:integer(argv[0],argv[0]))
          runerr(101, argv[0]);
      mysql = (MYSQL*)IntVal(argv[0]);

      if (argc < 2)
          runerr(101);
      if (!cnv:integer(argv[1],argv[1]))
          runerr(101, argv[1]);
      option = (enum mysql_option)IntVal(argv[1]);

      switch (option) {
          /*
           * These take a single mandatory int as an arg.
           */
          case MYSQL_OPT_CONNECT_TIMEOUT: {
              if (argc < 3)
                  runerr(101);
              if (!cnv:integer(argv[2],argv[2]))
                  runerr(101, argv[2]);
              int_arg = (unsigned int)IntVal(argv[2]);
              arg = (char*)&int_arg;
              break;
          }

          /*
           * These take a single optional int as an arg.
           */
          case MYSQL_OPT_LOCAL_INFILE: {
              if (argc < 3) {
                  arg = NULL;
              } else {
                  if (!cnv:integer(argv[2],argv[2]))
                      runerr(101, argv[2]);
                  int_arg = (unsigned int)IntVal(argv[2]);
                  arg = (char*)&int_arg;
              }
              break;
          }

          /*
           * These take a single mandatory char* as an arg.
           */
          case MYSQL_INIT_COMMAND:
          case MYSQL_READ_DEFAULT_FILE:
          case MYSQL_READ_DEFAULT_GROUP: {
              if (argc < 3)
                  runerr(103);
              if (!cnv:string(argv[2],argv[2]))
                  runerr(103, argv[2]);
              arg = StrLoc(argv[2]);
              break;
          }

          case MYSQL_OPT_COMPRESS:
          case MYSQL_OPT_NAMED_PIPE: {
              arg = NULL;
              break;
          }

          default: {
              fail;
          }
      }

      if (mysql_options(mysql, option, arg))
          fail;
      return nulldesc;
   }
end

function{0,1} unimysql_ping(id) 
   if !cnv:C_integer(id) then
       runerr(101, id)
   body {
      MYSQL *mysql = (MYSQL*)id;
      if (mysql_ping(mysql))
          fail;
      return nulldesc;
   }
end

function{1} unimysql_real_escape_string(id, str)
   if !cnv:C_integer(id) then
       runerr(101, id)
   if !cnv:string(str) then
       runerr(103, str)
   body {
      MYSQL *mysql = (MYSQL*)id;
      char *to;
      unsigned long to_len;
      Protect(to = malloc(2 * StrLen(str) + 1), runerr(0));
      to_len = mysql_real_escape_string(mysql, to, StrLoc(str), StrLen(str));
      result = bytes2string(to, to_len);
      free(to);
      return result;
   }
end

function{0,1} unimysql_select_db(id, db)
   if !cnv:C_integer(id) then
       runerr(101, id)
   if !cnv:C_string(db) then
       runerr(103, db)
   body {
      MYSQL *mysql = (MYSQL*)id;
      if (mysql_select_db(mysql, db))
          fail;
      return nulldesc;
   }
end

function{0,1} unimysql_shutdown(id)
   if !cnv:C_integer(id) then
       runerr(101, id)
   body {
      MYSQL *mysql = (MYSQL*)id;
      if (mysql_shutdown(mysql))
          fail;
      return nulldesc;
   }
end

function{0,1} unimysql_change_user(id, user, passwd, db)
   if !cnv:C_integer(id) then
       runerr(101, id)
   body {
      MYSQL *mysql = (MYSQL*)id;
      tended char *c_user;
      tended char *c_passwd;
      tended char *c_db;

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

      if (mysql_change_user(mysql, c_user, c_passwd, c_db))
          fail;
      return nulldesc;
   }
end

function{1} unimysql_character_set_name(id)
   if !cnv:C_integer(id) then
       runerr(101, id)
   body {
      MYSQL *mysql = (MYSQL*)id;
      return cstr2string((char*)mysql_character_set_name(mysql));
   }
end

function{0,1} unimysql_dump_debug_info(id)
   if !cnv:C_integer(id) then
       runerr(101, id)
   body {
      MYSQL *mysql = (MYSQL*)id;
      if (mysql_dump_debug_info(mysql))
          fail;
      return nulldesc;
   }
end

function{1} unimysql_get_client_info()
   body {
      return cstr2string((char*)mysql_get_client_info());
   }
end

function{1} unimysql_get_client_version()
   body {
      return C_integer mysql_get_client_version();
   }
end

function{1} unimysql_get_host_info(id)
   if !cnv:C_integer(id) then
       runerr(101, id)
   body {
      MYSQL *mysql = (MYSQL*)id;
      return cstr2string((char*)mysql_get_host_info(mysql));
   }
end

function{1} unimysql_sqlstate(id)
   if !cnv:C_integer(id) then
       runerr(101, id)
   body {
      MYSQL *mysql = (MYSQL*)id;
      return cstr2string((char*)mysql_sqlstate(mysql));
   }
end

function{1} unimysql_get_proto_info(id)
   if !cnv:C_integer(id) then
       runerr(101, id)
   body {
      MYSQL *mysql = (MYSQL*)id;
      return C_integer mysql_get_proto_info(mysql);
   }
end

function{1} unimysql_get_server_info(id)
   if !cnv:C_integer(id) then
       runerr(101, id)
   body {
      MYSQL *mysql = (MYSQL*)id;
      return cstr2string((char*)mysql_get_server_info(mysql));
   }
end

function{1} unimysql_get_server_version(id)
   if !cnv:C_integer(id) then
       runerr(101, id)
   body {
      MYSQL *mysql = (MYSQL*)id;
      return C_integer mysql_get_server_version(mysql);
   }
end

function{1} unimysql_info(id)
   if !cnv:C_integer(id) then
       runerr(101, id)
   body {
      MYSQL *mysql = (MYSQL*)id;
      return cstr2string((char*)mysql_info(mysql));
   }
end

function{0,1} unimysql_stat(id)
   if !cnv:C_integer(id) then
       runerr(101, id)
   body {
      MYSQL *mysql = (MYSQL*)id;
      char *s = (char*)mysql_stat(mysql);
      if (s == NULL)
          fail;
      return cstr2string(s);
   }
end

function{0,1} unimysql_commit(id)
   if !cnv:C_integer(id) then
       runerr(101, id)
   body {
      MYSQL *mysql = (MYSQL*)id;
      if (mysql_commit(mysql))
          fail;
      return nulldesc;
   }
end

function{0,1} unimysql_rollback(id)
   if !cnv:C_integer(id) then
       runerr(101, id)
   body {
      MYSQL *mysql = (MYSQL*)id;
      if (mysql_rollback(mysql))
          fail;
      return nulldesc;
   }
end

function{0,1} unimysql_autocommit(id, mode)
   if !cnv:C_integer(id) then
       runerr(101, id)
   if !cnv:C_integer(mode) then
       runerr(101, mode)
   body {
      MYSQL *mysql = (MYSQL*)id;
      if (mysql_autocommit(mysql, (my_bool)mode))
          fail;
      return nulldesc;
    }
end

function{0,1} unimysql_more_results(id)
   if !cnv:C_integer(id) then
       runerr(101, id)
   body {
      MYSQL *mysql = (MYSQL*)id;
      if (mysql_more_results(mysql))
          return nulldesc;
      else
          fail;
   }
end

function{0,1} unimysql_next_result(id)
   if !cnv:C_integer(id) then
       runerr(101, id)
   body {
      MYSQL *mysql = (MYSQL*)id;
      if (mysql_next_result(mysql))
          fail;
      return nulldesc;
    }
end

function{1} unimysql_affected_rows(id)
   if !cnv:C_integer(id) then
       runerr(101, id)
   body {
      MYSQL *mysql = (MYSQL*)id;
      return C_integer mysql_affected_rows(mysql);
   }
end

function{0,1} unimysql_real_connect(id, host, user, passwd, db, 
                                    port, unix_socket, client_flag)
   if !cnv:C_integer(id) then
       runerr(101, id)
   body {
      MYSQL *mysql = (MYSQL*)id;
      tended char *c_host;
      tended char *c_user;
      tended char *c_passwd;
      tended char *c_db;
      unsigned int c_port;
      tended char *c_unix_socket;
      unsigned int c_client_flag;

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
                              c_db, c_port, c_unix_socket, c_client_flag))
          fail;

      return nulldesc;
   }
end

function{0,1} unimysql_ssl_set(id, key, cert, ca, capath, cipher)
   if !cnv:C_integer(id) then
       runerr(101, id)
   body {
      MYSQL *mysql = (MYSQL*)id;
      tended char *c_key;
      tended char *c_cert;
      tended char *c_ca;
      tended char *c_capath;
      tended char *c_cipher;

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

function{1} unimysql_error(id)
   if !cnv:C_integer(id) then
       runerr(101, id)
   body {
      MYSQL *mysql = (MYSQL*)id;
      return cstr2string((char*)mysql_error(mysql));
   }
end

function{1} unimysql_errno(id)
   if !cnv:C_integer(id) then
       runerr(101, id)
   body {
      MYSQL *mysql = (MYSQL*)id;
      return C_integer mysql_errno(mysql);
   }
end

function{1} unimysql_thread_id(id)
   if !cnv:C_integer(id) then
       runerr(101, id)
   body {
      MYSQL *mysql = (MYSQL*)id;
      return C_integer mysql_thread_id(mysql);
   }
end

function{1} unimysql_warning_count(id)
   if !cnv:C_integer(id) then
       runerr(101, id)
   body {
      MYSQL *mysql = (MYSQL*)id;
      return C_integer mysql_warning_count(mysql);
   }
end

function{0,1} unimysql_query(id, q)
   if !cnv:C_integer(id) then
       runerr(101, id)
   if !cnv:string(q) then
       runerr(103, q)
   body {
      MYSQL *mysql = (MYSQL*)id;
      if (mysql_real_query(mysql, StrLoc(q), StrLen(q)))
          fail;
      return nulldesc;
   }
end

function{1} unimysql_field_count(id)
   if !cnv:C_integer(id) then
       runerr(101, id)
   body {
      MYSQL *mysql = (MYSQL*)id;
      return C_integer mysql_field_count(mysql);
   }
end

function{1} unimysql_insert_id(id)
   if !cnv:C_integer(id) then
       runerr(101, id)
   body {
      MYSQL *mysql = (MYSQL*)id;
      return C_integer mysql_insert_id(mysql);
   }
end

function{0,1} unimysql_kill(id, pid)
   if !cnv:C_integer(id) then
       runerr(101, id)
   if !cnv:C_integer(pid) then
       runerr(101, pid)
   body {
      MYSQL *mysql = (MYSQL*)id;
      if (mysql_kill(mysql, pid))
          fail;
      return nulldesc;
   }
end

function{0,1} unimysql_list_dbs(id, wild)
   if !cnv:C_integer(id) then
       runerr(101, id)
   body {
      MYSQL *mysql = (MYSQL*)id;
      MYSQL_RES *res;
      tended char *c_wild;

      if (is:null(wild))
          c_wild = NULL;
      else if (!cnv:C_string(wild, c_wild))
          runerr(103, wild);

      res = mysql_list_dbs(mysql, c_wild);
      if (!res)
          fail;
      return C_integer((long int)res);
   }
end

function{0,1} unimysql_list_fields(id, table, wild)
   if !cnv:C_integer(id) then
       runerr(101, id)
   body {
      MYSQL *mysql = (MYSQL*)id;
      MYSQL_RES *res;
      tended char *c_table;
      tended char *c_wild;

      if (!cnv:C_string(table, c_table))
          runerr(103, table);

      if (is:null(wild))
          c_wild = NULL;
      else if (!cnv:C_string(wild, c_wild))
          runerr(103, wild);

      res = mysql_list_fields(mysql, c_table, c_wild);
      if (!res)
          fail;
      return C_integer((long int)res);
   }
end

function{0,1} unimysql_list_processes(id)
   if !cnv:C_integer(id) then
       runerr(101, id)
   body {
      MYSQL *mysql = (MYSQL*)id;
      MYSQL_RES *res = mysql_list_processes(mysql);
      if (!res)
          fail;
      return C_integer((long int)res);
   }
end

function{0,1} unimysql_list_tables(id, wild)
   if !cnv:C_integer(id) then
       runerr(101, id)
   body {
      MYSQL *mysql = (MYSQL*)id;
      MYSQL_RES *res;
      tended char *c_wild;

      if (is:null(wild))
          c_wild = NULL;
      else if (!cnv:C_string(wild, c_wild))
          runerr(103, wild);

      res = mysql_list_tables(mysql, c_wild);
      if (!res)
          fail;
      return C_integer((long int)res);
   }
end

function{0,1} unimysql_use_result(id)
   if !cnv:C_integer(id) then
       runerr(101, id)
   body {
      MYSQL *mysql = (MYSQL*)id;
      MYSQL_RES *res = mysql_use_result(mysql);
      if (!res)
          fail;
      return C_integer((long int)res);
   }
end

function{0,1} unimysql_store_result(id)
   if !cnv:C_integer(id) then
       runerr(101, id)
   body {
      MYSQL *mysql = (MYSQL*)id;
      MYSQL_RES *res = mysql_store_result(mysql);
      if (!res)
          fail;
      return C_integer((long int)res);
   }
end

function{1} unimysql_num_fields(id)
   if !cnv:C_integer(id) then
       runerr(101, id)
   body {
       MYSQL_RES *mysql_res = (MYSQL_RES*)id;
       return C_integer mysql_num_fields(mysql_res);
   }
end

function{0,1} unimysql_fetch_field(id)
   if !cnv:C_integer(id) then
       runerr(101, id)
   body {
       MYSQL_RES *mysql_res = (MYSQL_RES*)id;
       MYSQL_FIELD *field = mysql_fetch_field(mysql_res);
       if (!field)
           fail;
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

function{0,1} unimysql_fetch_field_direct(id, fieldnr)
   if !cnv:C_integer(id) then
       runerr(101, id)
   if !cnv:C_integer(fieldnr) then
       runerr(101, fieldnr)
   body {
       MYSQL_RES *mysql_res = (MYSQL_RES*)id;
       MYSQL_FIELD *field = mysql_fetch_field_direct(mysql_res, fieldnr);
       if (!field)
           fail;
       return field_to_list(field);
   }
end

function{0,1} unimysql_fetch_fields(id)
   if !cnv:C_integer(id) then
       runerr(101, id)
   body {
       MYSQL_RES *mysql_res = (MYSQL_RES*)id;
       MYSQL_FIELD *fields;
       int i, n;

       fields = mysql_fetch_fields(mysql_res);
       if (!fields)
           fail;

       n = mysql_num_fields(mysql_res);
       result = create_list(n);
       for (i = 0; i < n; ++i) {
           tended struct descrip tmp = field_to_list(&fields[i]);
           c_put(&result, &tmp);
       }
       return result;
   }
end

function{1} unimysql_field_seek(id, offset)
   if !cnv:C_integer(id) then
       runerr(101, id)
   if !cnv:C_integer(offset) then
       runerr(101, offset)
   body {
       MYSQL_RES *mysql_res = (MYSQL_RES*)id;
       return C_integer mysql_field_seek(mysql_res, (MYSQL_FIELD_OFFSET)offset);
   }
end

function{1} unimysql_field_tell(id)
   if !cnv:C_integer(id) then
       runerr(101, id)
   body {
       MYSQL_RES *mysql_res = (MYSQL_RES*)id;
       return C_integer mysql_field_tell(mysql_res);
   }
end

function{0,1} unimysql_fetch_lengths(id)
   if !cnv:C_integer(id) then
       runerr(101, id)
   body {
       MYSQL_RES *mysql_res = (MYSQL_RES*)id;
       int i, n;
       unsigned long *lengths = mysql_fetch_lengths(mysql_res);
       if (!lengths)
           fail;
       n = mysql_num_fields(mysql_res);
       result = create_list(n);
       for (i = 0; i < n; ++i) {
           tended struct descrip tmp;
           MakeInt(lengths[i], &tmp);
           c_put(&result, &tmp);
       }
       return result;
   }
end

function{0,1} unimysql_fetch_row(id)
   if !cnv:C_integer(id) then
       runerr(101, id)
   body {
       MYSQL_RES *mysql_res = (MYSQL_RES*)id;
       int i, n;
       unsigned long *lengths;
       MYSQL_ROW row;

       row = mysql_fetch_row(mysql_res);
       if (!row)
           fail;
       lengths = mysql_fetch_lengths(mysql_res);
       if (!lengths)
           fail;

       n = mysql_num_fields(mysql_res);
       result = create_list(n);
       for (i = 0; i < n; ++i) {
           tended struct descrip tmp = bytes2string(row[i], lengths[i]);
           c_put(&result, &tmp);
       }
       return result;
   }
end

function{1} unimysql_row_seek(id, offset)
   if !cnv:C_integer(id) then
       runerr(101, id)
   if !cnv:C_integer(offset) then
       runerr(101, offset)
   body {
       MYSQL_RES *mysql_res = (MYSQL_RES*)id;
       return C_integer((long int)mysql_row_seek(mysql_res, (MYSQL_ROW_OFFSET)offset));
   }
end

function{1} unimysql_row_tell(id)
   if !cnv:C_integer(id) then
       runerr(101, id)
   body {
       MYSQL_RES *mysql_res = (MYSQL_RES*)id;
       return C_integer((long int)mysql_row_tell(mysql_res));
   }
end

function{1} unimysql_data_seek(id, offset)
   if !cnv:C_integer(id) then
       runerr(101, id)
   if !cnv:C_integer(offset) then
       runerr(101, offset)
   body {
       MYSQL_RES *mysql_res = (MYSQL_RES*)id;
       mysql_data_seek(mysql_res, (my_ulonglong)offset);
       return nulldesc;
   }
end

function{1} unimysql_num_rows(id)
   if !cnv:C_integer(id) then
       runerr(101, id)
   body {
       MYSQL_RES *mysql_res = (MYSQL_RES*)id;
       return C_integer mysql_num_rows(mysql_res);
   }
end

function{1} unimysql_free_result(id)
   if !cnv:C_integer(id) then
       runerr(101, id)
   body {
       MYSQL_RES *mysql_res = (MYSQL_RES*)id;
       mysql_free_result(mysql_res);
       return nulldesc;
   }
end
