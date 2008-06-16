#include <stdio.h>
#include <stdlib.h>

#include "rt.h"
#undef column
#include "mysql.h"
#include "nativeutils.h"

static struct descrip field_to_list(MYSQL_FIELD *field);

int unimysql_init(int argc, struct descrip *argv) {
    MYSQL *res;

    res = mysql_init(NULL);

    if (res == NULL) {
        return -1;
    }

   MakeInt((long int)res, &argv[0]);

   return 0;
}

int unimysql_close(int argc, struct descrip *argv) {
    MYSQL *mysql;

   if (argc < 1)
      return 101;
   if (!cnv_int(&argv[1], &argv[1])) {
      argv[0] = argv[1];
      return 101;
   }
   mysql = (MYSQL*)IntVal(argv[1]);

   mysql_close(mysql);

   return 0;
}

int unimysql_set_server_option(int argc, struct descrip *argv) {
    MYSQL *mysql;
    enum enum_mysql_set_option option;

   if (argc < 1)
      return 101;
   if (!cnv_int(&argv[1], &argv[1])) {
      argv[0] = argv[1];
      return 101;
   }
   mysql = (MYSQL*)IntVal(argv[1]);

   if (argc < 2)
      return 101;
   if (!cnv_int(&argv[2], &argv[2])) {
      argv[0] = argv[2];
      return 101;
   }
   option = (enum enum_mysql_set_option)IntVal(argv[2]);

   return mysql_set_server_option(mysql, option) ? -1:0;
}

int unimysql_options(int argc, struct descrip *argv) {
    MYSQL *mysql;
    enum mysql_option option;
    char *arg;
    unsigned int int_arg;

   if (argc < 1)
      return 101;
   if (!cnv_int(&argv[1], &argv[1])) {
      argv[0] = argv[1];
      return 101;
   }
   mysql = (MYSQL*)IntVal(argv[1]);

   if (argc < 2)
      return 101;
   if (!cnv_int(&argv[2], &argv[2])) {
      argv[0] = argv[2];
      return 101;
   }
   option = (enum mysql_option)IntVal(argv[2]);

   switch (option) {
       /*
        * These take a single mandatory int as an arg.
        */
       case MYSQL_OPT_CONNECT_TIMEOUT: {
           if (argc < 3)
               return 101;
           if (!cnv_int(&argv[3], &argv[3])) {
               argv[0] = argv[3];
               return 101;
           }
           int_arg = (unsigned int)IntVal(argv[3]);
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
               if (!cnv_int(&argv[3], &argv[3])) {
                   argv[0] = argv[3];
                   return 101;
               }
               int_arg = (unsigned int)IntVal(argv[3]);
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
               return 103;
           if (!cnv_c_str(&argv[3], &argv[3])) {
               argv[0] = argv[3];
               return 103;
           }
           arg = StrLoc(argv[3]);
           break;
       }

       case MYSQL_OPT_COMPRESS:
       case MYSQL_OPT_NAMED_PIPE: {
           arg = NULL;
           break;
       }

       default: {
           return -1;
       }
   }

   return mysql_options(mysql, option, arg) ? -1:0;
}

int unimysql_ping(int argc, struct descrip *argv) {
    MYSQL *mysql;

   if (argc < 1)
      return 101;
   if (!cnv_int(&argv[1], &argv[1])) {
      argv[0] = argv[1];
      return 101;
   }
   mysql = (MYSQL*)IntVal(argv[1]);

   return mysql_ping(mysql) ? -1:0;

   return 0;
}

int unimysql_real_escape_string(int argc, struct descrip *argv) {
    MYSQL *mysql;
    char *to;
    unsigned long to_len;

   if (argc < 1)
      return 101;
   if (!cnv_int(&argv[1], &argv[1])) {
      argv[0] = argv[1];
      return 101;
   }
   mysql = (MYSQL*)IntVal(argv[1]);

   if (argc < 2)
       return 103;
   if (!cnv_str(&argv[2], &argv[2])) {
       argv[0] = argv[2];
       return 103;
   }

   to = malloc(2 * StrLen(argv[2]) + 1);
   if (to == NULL)
       return -1;

   to_len = mysql_real_escape_string(mysql, to, StrLoc(argv[2]), StrLen(argv[2]));
   argv[0] = create_string2(to, to_len);

   free(to);

   return 0;
}

int unimysql_select_db(int argc, struct descrip *argv) {
    MYSQL *mysql;
    char *db;

   if (argc < 1)
      return 101;
   if (!cnv_int(&argv[1], &argv[1])) {
      argv[0] = argv[1];
      return 101;
   }
   mysql = (MYSQL*)IntVal(argv[1]);

   if (argc < 2)
       return 103;
   if (!cnv_c_str(&argv[2], &argv[2])) {
       argv[0] = argv[2];
       return 103;
   }
   db = StrLoc(argv[2]);

   return mysql_select_db(mysql, db) ? -1:0;
}

int unimysql_shutdown(int argc, struct descrip *argv) {
    MYSQL *mysql;

   if (argc < 1)
      return 101;
   if (!cnv_int(&argv[1], &argv[1])) {
      argv[0] = argv[1];
      return 101;
   }
   mysql = (MYSQL*)IntVal(argv[1]);

   return mysql_shutdown(mysql) ? -1:0;
}


int unimysql_change_user(int argc, struct descrip *argv) {
   MYSQL *mysql;
   char *user;
   char *passwd;
   char *db;

   if (argc < 1)
      return 101;
   if (!cnv_int(&argv[1], &argv[1])) {
      argv[0] = argv[1];
      return 101;
   }
   mysql = (MYSQL*)IntVal(argv[1]);

   if (argc < 2 || ChkNull(argv[2])) {
       user = NULL;
   } else {
       if (!cnv_c_str(&argv[2], &argv[2])) {
           argv[0] = argv[2];
           return 103;
       }
       user = StrLoc(argv[2]);
   }

   if (argc < 3 || ChkNull(argv[3])) {
       passwd = NULL;
   } else {
       if (!cnv_c_str(&argv[3], &argv[3])) {
           argv[0] = argv[3];
           return 103;
       }
       passwd = StrLoc(argv[3]);
   }

   if (argc < 4 || ChkNull(argv[4])) {
       db = NULL;
   } else {
       if (!cnv_c_str(&argv[4], &argv[4])) {
           argv[0] = argv[4];
           return 103;
       }
       db = StrLoc(argv[4]);
   }

   return mysql_change_user(mysql, user, passwd, db) ? -1:0;
}

int unimysql_character_set_name(int argc, struct descrip *argv) {
   MYSQL *mysql;

   if (argc < 1)
      return 101;
   if (!cnv_int(&argv[1], &argv[1])) {
      argv[0] = argv[1];
      return 101;
   }
   mysql = (MYSQL*)IntVal(argv[1]);

   argv[0] = create_string((char*)mysql_character_set_name(mysql));

   return 0;
}

int unimysql_dump_debug_info(int argc, struct descrip *argv) {
   MYSQL *mysql;
   char *s;

   if (argc < 1)
      return 101;
   if (!cnv_int(&argv[1], &argv[1])) {
      argv[0] = argv[1];
      return 101;
   }
   mysql = (MYSQL*)IntVal(argv[1]);

   return mysql_dump_debug_info(mysql)?-1:0;
}

int unimysql_get_client_info(int argc, struct descrip *argv) {
   argv[0] = create_string((char*)mysql_get_client_info());
   return 0;
}

int unimysql_get_client_version(int argc, struct descrip *argv) {
   MakeInt(mysql_get_client_version(), &argv[0]);
   return 0;
}

int unimysql_get_host_info(int argc, struct descrip *argv) {
   MYSQL *mysql;

   if (argc < 1)
      return 101;
   if (!cnv_int(&argv[1], &argv[1])) {
      argv[0] = argv[1];
      return 101;
   }
   mysql = (MYSQL*)IntVal(argv[1]);

   argv[0] = create_string((char*)mysql_get_host_info(mysql));

   return 0;
}

int unimysql_sqlstate(int argc, struct descrip *argv) {
   MYSQL *mysql;

   if (argc < 1)
      return 101;
   if (!cnv_int(&argv[1], &argv[1])) {
      argv[0] = argv[1];
      return 101;
   }
   mysql = (MYSQL*)IntVal(argv[1]);

   argv[0] = create_string((char*)mysql_sqlstate(mysql));

   return 0;
}

int unimysql_get_proto_info(int argc, struct descrip *argv) {
   MYSQL *mysql;

   if (argc < 1)
      return 101;
   if (!cnv_int(&argv[1], &argv[1])) {
      argv[0] = argv[1];
      return 101;
   }
   mysql = (MYSQL*)IntVal(argv[1]);

   MakeInt(mysql_get_proto_info(mysql), &argv[0]);

   return 0;
}

int unimysql_get_server_info(int argc, struct descrip *argv) {
   MYSQL *mysql;

   if (argc < 1)
      return 101;
   if (!cnv_int(&argv[1], &argv[1])) {
      argv[0] = argv[1];
      return 101;
   }
   mysql = (MYSQL*)IntVal(argv[1]);

   argv[0] = create_string((char*)mysql_get_server_info(mysql));

   return 0;
}

int unimysql_get_server_version(int argc, struct descrip *argv) {
   MYSQL *mysql;

   if (argc < 1)
      return 101;
   if (!cnv_int(&argv[1], &argv[1])) {
      argv[0] = argv[1];
      return 101;
   }
   mysql = (MYSQL*)IntVal(argv[1]);

   MakeInt(mysql_get_server_version(mysql), &argv[0]);

   return 0;
}

int unimysql_info(int argc, struct descrip *argv) {
   MYSQL *mysql;

   if (argc < 1)
      return 101;
   if (!cnv_int(&argv[1], &argv[1])) {
      argv[0] = argv[1];
      return 101;
   }
   mysql = (MYSQL*)IntVal(argv[1]);

   argv[0] = create_string((char*)mysql_info(mysql));

   return 0;
}

int unimysql_stat(int argc, struct descrip *argv) {
   MYSQL *mysql;
   char *s;

   if (argc < 1)
      return 101;
   if (!cnv_int(&argv[1], &argv[1])) {
      argv[0] = argv[1];
      return 101;
   }
   mysql = (MYSQL*)IntVal(argv[1]);

   s = (char*)mysql_stat(mysql);
   if (s == NULL)
       return -1;

   argv[0] = create_string(s);

   return 0;
}

int unimysql_commit(int argc, struct descrip *argv) {
   MYSQL *mysql;
   char *s;

   if (argc < 1)
      return 101;
   if (!cnv_int(&argv[1], &argv[1])) {
      argv[0] = argv[1];
      return 101;
   }
   mysql = (MYSQL*)IntVal(argv[1]);

   return mysql_commit(mysql) ? -1:0;
}

int unimysql_rollback(int argc, struct descrip *argv) {
   MYSQL *mysql;
   char *s;

   if (argc < 1)
      return 101;
   if (!cnv_int(&argv[1], &argv[1])) {
      argv[0] = argv[1];
      return 101;
   }
   mysql = (MYSQL*)IntVal(argv[1]);

   return mysql_rollback(mysql) ? -1:0;
}

int unimysql_autocommit(int argc, struct descrip *argv) {
   MYSQL *mysql;
   char *s;
   my_bool mode;

   if (argc < 1)
      return 101;
   if (!cnv_int(&argv[1], &argv[1])) {
      argv[0] = argv[1];
      return 101;
   }
   mysql = (MYSQL*)IntVal(argv[1]);

   if (argc < 2)
       return 101;
   if (!cnv_int(&argv[2], &argv[2])) {
       argv[0] = argv[2];
       return 101;
   }
   mode = (my_bool)IntVal(argv[2]);

   return mysql_autocommit(mysql, mode) ? -1:0;
}

int unimysql_more_results(int argc, struct descrip *argv) {
   MYSQL *mysql;
   char *s;

   if (argc < 1)
      return 101;
   if (!cnv_int(&argv[1], &argv[1])) {
      argv[0] = argv[1];
      return 101;
   }
   mysql = (MYSQL*)IntVal(argv[1]);

   return mysql_more_results(mysql) ? 0:-1;
}

int unimysql_next_result(int argc, struct descrip *argv) {
   MYSQL *mysql;
   char *s;

   if (argc < 1)
      return 101;
   if (!cnv_int(&argv[1], &argv[1])) {
      argv[0] = argv[1];
      return 101;
   }
   mysql = (MYSQL*)IntVal(argv[1]);

   return mysql_next_result(mysql) ? -1:0;
}

int unimysql_affected_rows(int argc, struct descrip *argv) {
    MYSQL *mysql;

   if (argc < 1)
      return 101;
   if (!cnv_int(&argv[1], &argv[1])) {
      argv[0] = argv[1];
      return 101;
   }
   mysql = (MYSQL*)IntVal(argv[1]);

   MakeInt(mysql_affected_rows(mysql), &argv[0]);

   return 0;
}

int unimysql_real_connect(int argc, struct descrip *argv) {
   MYSQL *mysql;
   char *host;
   char *user;
   char *passwd;
   char *db;
   unsigned int port;
   char *unix_socket;
   unsigned long client_flag;

   if (argc < 1)
      return 101;
   if (!cnv_int(&argv[1], &argv[1])) {
      argv[0] = argv[1];
      return 101;
   }
   mysql = (MYSQL*)IntVal(argv[1]);

   if (argc < 2 || ChkNull(argv[2])) {
       host = NULL;
   } else {
       if (!cnv_c_str(&argv[2], &argv[2])) {
           argv[0] = argv[2];
           return 103;
       }
       host = StrLoc(argv[2]);
   }

   if (argc < 3 || ChkNull(argv[3])) {
       user = NULL;
   } else {
       if (!cnv_c_str(&argv[3], &argv[3])) {
           argv[0] = argv[3];
           return 103;
       }
       user = StrLoc(argv[3]);
   }

   if (argc < 4 || ChkNull(argv[4])) {
       passwd = NULL;
   } else {
       if (!cnv_c_str(&argv[4], &argv[4])) {
           argv[0] = argv[4];
           return 103;
       }
       passwd = StrLoc(argv[4]);
   }

   if (argc < 5 || ChkNull(argv[5])) {
       db = NULL;
   } else {
       if (!cnv_c_str(&argv[5], &argv[5])) {
           argv[0] = argv[5];
           return 103;
       }
       db = StrLoc(argv[5]);
   }

   if (argc < 6 || ChkNull(argv[6])) {
       port = 0;
   } else {
       if (!cnv_int(&argv[6], &argv[6])) {
           argv[0] = argv[6];
           return 101;
       }
       port = IntVal(argv[6]);
   }

   if (argc < 7 || ChkNull(argv[7])) {
       unix_socket = NULL;
   } else {
       if (!cnv_c_str(&argv[7], &argv[7])) {
           argv[0] = argv[7];
           return 103;
       }
       unix_socket = StrLoc(argv[7]);
   }

   if (argc < 8 || ChkNull(argv[8])) {
       client_flag = 0;
   } else {
       if (!cnv_int(&argv[8], &argv[8])) {
           argv[0] = argv[8];
           return 101;
       }
       client_flag = IntVal(argv[8]);
   }

   return mysql_real_connect(mysql, host, user, passwd, db, port, unix_socket, client_flag) ? 0:-1;
}

int unimysql_ssl_set(int argc, struct descrip *argv) {
   MYSQL *mysql;
   char *key;
   char *cert;
   char *ca;
   char *capath;
   char *cipher;

   if (argc < 1)
      return 101;
   if (!cnv_int(&argv[1], &argv[1])) {
      argv[0] = argv[1];
      return 101;
   }
   mysql = (MYSQL*)IntVal(argv[1]);

   if (argc < 2 || ChkNull(argv[2])) {
       key = NULL;
   } else {
       if (!cnv_c_str(&argv[2], &argv[2])) {
           argv[0] = argv[2];
           return 103;
       }
       key = StrLoc(argv[2]);
   }

   if (argc < 3 || ChkNull(argv[3])) {
       cert = NULL;
   } else {
       if (!cnv_c_str(&argv[3], &argv[3])) {
           argv[0] = argv[3];
           return 103;
       }
       cert = StrLoc(argv[3]);
   }

   if (argc < 4 || ChkNull(argv[4])) {
       ca = NULL;
   } else {
       if (!cnv_c_str(&argv[4], &argv[4])) {
           argv[0] = argv[4];
           return 103;
       }
       ca = StrLoc(argv[4]);
   }

   if (argc < 5 || ChkNull(argv[5])) {
       capath = NULL;
   } else {
       if (!cnv_c_str(&argv[5], &argv[5])) {
           argv[0] = argv[5];
           return 103;
       }
       capath = StrLoc(argv[5]);
   }

   if (argc < 6 || ChkNull(argv[6])) {
       cipher = NULL;
   } else {
       if (!cnv_c_str(&argv[6], &argv[6])) {
           argv[0] = argv[6];
           return 103;
       }
       cipher = StrLoc(argv[6]);
   }

   mysql_ssl_set(mysql, key, cert, ca, capath, cipher);

   return 0;
}

int unimysql_error(int argc, struct descrip *argv) {
   MYSQL *mysql;
   char *s;

   if (argc < 1)
      return 101;
   if (!cnv_int(&argv[1], &argv[1])) {
      argv[0] = argv[1];
      return 101;
   }
   mysql = (MYSQL*)IntVal(argv[1]);

   argv[0] = create_string((char*)mysql_error(mysql));

   return 0;
}

int unimysql_errno(int argc, struct descrip *argv) {
   MYSQL *mysql;
   char *s;

   if (argc < 1)
      return 101;
   if (!cnv_int(&argv[1], &argv[1])) {
      argv[0] = argv[1];
      return 101;
   }
   mysql = (MYSQL*)IntVal(argv[1]);

   MakeInt(mysql_errno(mysql), &argv[0]);

   return 0;
}

int unimysql_thread_id(int argc, struct descrip *argv) {
   MYSQL *mysql;
   char *s;

   if (argc < 1)
      return 101;
   if (!cnv_int(&argv[1], &argv[1])) {
      argv[0] = argv[1];
      return 101;
   }
   mysql = (MYSQL*)IntVal(argv[1]);

   MakeInt(mysql_thread_id(mysql), &argv[0]);

   return 0;
}

int unimysql_warning_count(int argc, struct descrip *argv) {
   MYSQL *mysql;
   char *s;

   if (argc < 1)
      return 101;
   if (!cnv_int(&argv[1], &argv[1])) {
      argv[0] = argv[1];
      return 101;
   }
   mysql = (MYSQL*)IntVal(argv[1]);

   MakeInt(mysql_warning_count(mysql), &argv[0]);

   return 0;
}

int unimysql_query(int argc, struct descrip *argv) {
   MYSQL *mysql;

   if (argc < 1)
      return 101;
   if (!cnv_int(&argv[1], &argv[1])) {
      argv[0] = argv[1];
      return 101;
   }
   mysql = (MYSQL*)IntVal(argv[1]);

   if (argc < 2)
       return 103;
   if (!cnv_str(&argv[2], &argv[2])) {
       argv[0] = argv[2];
       return 103;
   }
   
   return mysql_real_query(mysql, StrLoc(argv[2]), StrLen(argv[2])) ? -1:0;
}

int unimysql_field_count(int argc, struct descrip *argv) {
   MYSQL *mysql;

   if (argc < 1)
      return 101;
   if (!cnv_int(&argv[1], &argv[1])) {
      argv[0] = argv[1];
      return 101;
   }
   mysql = (MYSQL*)IntVal(argv[1]);

   MakeInt(mysql_field_count(mysql), &argv[0]);

   return 0;
}

int unimysql_insert_id(int argc, struct descrip *argv) {
   MYSQL *mysql;

   if (argc < 1)
      return 101;
   if (!cnv_int(&argv[1], &argv[1])) {
      argv[0] = argv[1];
      return 101;
   }
   mysql = (MYSQL*)IntVal(argv[1]);

   MakeInt(mysql_insert_id(mysql), &argv[0]);

   return 0;
}

int unimysql_kill(int argc, struct descrip *argv) {
   MYSQL *mysql;
   unsigned long pid;

   if (argc < 1)
      return 101;
   if (!cnv_int(&argv[1], &argv[1])) {
      argv[0] = argv[1];
      return 101;
   }
   mysql = (MYSQL*)IntVal(argv[1]);

   if (argc < 2)
       return 101;
   if (!cnv_int(&argv[2], &argv[2])) {
       argv[0] = argv[2];
       return 101;
   }
   pid = IntVal(argv[2]);

   return mysql_kill(mysql, pid)?-1:0;

   return 0;
}

int unimysql_list_dbs(int argc, struct descrip *argv) {
   MYSQL *mysql;
   MYSQL_RES *res;
   char *wild;

   if (argc < 1)
      return 101;
   if (!cnv_int(&argv[1], &argv[1])) {
      argv[0] = argv[1];
      return 101;
   }
   mysql = (MYSQL*)IntVal(argv[1]);

   if (argc < 2 || ChkNull(argv[2])) {
       wild = NULL;
   } else {
       if (!cnv_c_str(&argv[2], &argv[2])) {
           argv[0] = argv[2];
           return 103;
       }
       wild = StrLoc(argv[2]);
   }

   res = mysql_list_dbs(mysql, wild);
   if (res == NULL) {
       return -1;
   }
   
   MakeInt((long int)res, &argv[0]);

   return 0;
}

int unimysql_list_fields(int argc, struct descrip *argv) {
   MYSQL *mysql;
   MYSQL_RES *res;
   char *table;
   char *wild;

   if (argc < 1)
      return 101;
   if (!cnv_int(&argv[1], &argv[1])) {
      argv[0] = argv[1];
      return 101;
   }
   mysql = (MYSQL*)IntVal(argv[1]);

   if (argc < 2)
       return 103;
   if (!cnv_c_str(&argv[2], &argv[2])) {
       argv[0] = argv[2];
       return 103;
   }
   table = StrLoc(argv[2]);

   if (argc < 3 || ChkNull(argv[3])) {
       wild = NULL;
   } else {
       if (!cnv_c_str(&argv[3], &argv[3])) {
           argv[0] = argv[3];
           return 103;
       }
       wild = StrLoc(argv[3]);
   }

   res = mysql_list_fields(mysql, table, wild);
   if (res == NULL) {
       return -1;
   }
   
   MakeInt((long int)res, &argv[0]);

   return 0;
}

int unimysql_list_processes(int argc, struct descrip *argv) {
   MYSQL *mysql;
   MYSQL_RES *res;
   char *wild;

   if (argc < 1)
      return 101;
   if (!cnv_int(&argv[1], &argv[1])) {
      argv[0] = argv[1];
      return 101;
   }
   mysql = (MYSQL*)IntVal(argv[1]);

   res = mysql_list_processes(mysql);
   if (res == NULL) {
       return -1;
   }
   
   MakeInt((long int)res, &argv[0]);

   return 0;
}

int unimysql_list_tables(int argc, struct descrip *argv) {
   MYSQL *mysql;
   MYSQL_RES *res;
   char *wild;

   if (argc < 1)
      return 101;
   if (!cnv_int(&argv[1], &argv[1])) {
      argv[0] = argv[1];
      return 101;
   }
   mysql = (MYSQL*)IntVal(argv[1]);

   if (argc < 2 || ChkNull(argv[2])) {
       wild = NULL;
   } else {
       if (!cnv_c_str(&argv[2], &argv[2])) {
           argv[0] = argv[2];
           return 103;
       }
       wild = StrLoc(argv[2]);
   }

   res = mysql_list_tables(mysql, wild);
   if (res == NULL) {
       return -1;
   }
   
   MakeInt((long int)res, &argv[0]);

   return 0;
}

int unimysql_use_result(int argc, struct descrip *argv) {
   MYSQL *mysql;
   MYSQL_RES *res;

   if (argc < 1)
      return 101;
   if (!cnv_int(&argv[1], &argv[1])) {
      argv[0] = argv[1];
      return 101;
   }
   mysql = (MYSQL*)IntVal(argv[1]);

   res = mysql_use_result(mysql);
   if (res == NULL) {
       return -1;
   }
   
   MakeInt((long int)res, &argv[0]);

   return 0;
}

int unimysql_store_result(int argc, struct descrip *argv) {
   MYSQL *mysql;
   MYSQL_RES *res;

   if (argc < 1)
      return 101;
   if (!cnv_int(&argv[1], &argv[1])) {
      argv[0] = argv[1];
      return 101;
   }
   mysql = (MYSQL*)IntVal(argv[1]);

   res = mysql_store_result(mysql);
   if (res == NULL) {
       return -1;
   }
   
   MakeInt((long int)res, &argv[0]);

   return 0;
}

int unimysql_num_fields(int argc, struct descrip *argv) {
   MYSQL_RES *mysql_res;

   int n;

   if (argc < 1)
      return 101;
   if (!cnv_int(&argv[1], &argv[1])) {
      argv[0] = argv[1];
      return 101;
   }
   mysql_res = (MYSQL_RES*)IntVal(argv[1]);

   MakeInt(mysql_num_fields(mysql_res), &argv[0]);

   return 0;
}

int unimysql_fetch_field(int argc, struct descrip *argv) {
   MYSQL_RES *mysql_res;
   MYSQL_FIELD *field;

   if (argc < 1)
      return 101;
   if (!cnv_int(&argv[1], &argv[1])) {
      argv[0] = argv[1];
      return 101;
   }
   mysql_res = (MYSQL_RES*)IntVal(argv[1]);

   field = mysql_fetch_field(mysql_res);
   if (field == NULL) {
       return -1;
   }

   argv[0] = field_to_list(field);

   return 0;
}

static struct descrip field_to_list(MYSQL_FIELD *field) {
   struct descrip tmp;
   struct tend_desc safe;
   dptr res = add_tended(&safe);

   *res = create_empty_list();

   tmp = create_string(field->name);
   c_put(res, &tmp);
   tmp = create_string(field->table);
   c_put(res, &tmp);
   tmp = create_string(field->org_table);
   c_put(res, &tmp);
   tmp = create_string(field->db);
   c_put(res, &tmp);
   tmp = create_string(field->def);
   c_put(res, &tmp);
   MakeInt(field->length, &tmp);
   c_put(res, &tmp);
   MakeInt(field->max_length, &tmp);
   c_put(res, &tmp);
   MakeInt(field->flags, &tmp);
   c_put(res, &tmp);
   MakeInt(field->decimals, &tmp);
   c_put(res, &tmp);
   MakeInt(field->type, &tmp);
   c_put(res, &tmp);

   rm_tended(&safe);

   return *res;
}

int unimysql_fetch_field_direct(int argc, struct descrip *argv) {
   MYSQL_RES *mysql_res;
   MYSQL_FIELD *field;
   int fieldnr;

   if (argc < 1)
      return 101;
   if (!cnv_int(&argv[1], &argv[1])) {
      argv[0] = argv[1];
      return 101;
   }
   mysql_res = (MYSQL_RES*)IntVal(argv[1]);

   if (argc < 2)
       return 101;
   if (!cnv_int(&argv[2], &argv[2])) {
       argv[0] = argv[2];
       return 101;
   }
   fieldnr = IntVal(argv[2]);

   field = mysql_fetch_field_direct(mysql_res, fieldnr);
   if (field == NULL) {
       return -1;
   }

   argv[0] = field_to_list(field);

   return 0;
}

int unimysql_fetch_fields(int argc, struct descrip *argv) {
   MYSQL_RES *mysql_res;
   MYSQL_FIELD *fields;
   int i, n;

   if (argc < 1)
      return 101;
   if (!cnv_int(&argv[1], &argv[1])) {
      argv[0] = argv[1];
      return 101;
   }
   mysql_res = (MYSQL_RES*)IntVal(argv[1]);

   fields = mysql_fetch_fields(mysql_res);
   if (fields == NULL) {
       return -1;
   }

   argv[0] = create_empty_list();
   n = mysql_num_fields(mysql_res);
   for (i = 0; i < n; ++i) {
       struct descrip tmp = field_to_list(&fields[i]);
       c_put(&argv[0], &tmp);
   }

   return 0;
}

int unimysql_field_seek(int argc, struct descrip *argv) {
   MYSQL_RES *mysql_res;
   MYSQL_FIELD_OFFSET offset;

   if (argc < 1)
      return 101;
   if (!cnv_int(&argv[1], &argv[1])) {
      argv[0] = argv[1];
      return 101;
   }
   mysql_res = (MYSQL_RES*)IntVal(argv[1]);

   if (argc < 2)
       return 101;
   if (!cnv_int(&argv[2], &argv[2])) {
       argv[0] = argv[2];
       return 101;
   }
   offset = (MYSQL_FIELD_OFFSET) IntVal(argv[2]);

   MakeInt(mysql_field_seek(mysql_res, offset), &argv[0]);

   return 0;
}

int unimysql_field_tell(int argc, struct descrip *argv) {
   MYSQL_RES *mysql_res;

   if (argc < 1)
      return 101;
   if (!cnv_int(&argv[1], &argv[1])) {
      argv[0] = argv[1];
      return 101;
   }
   mysql_res = (MYSQL_RES*)IntVal(argv[1]);

   MakeInt(mysql_field_tell(mysql_res), &argv[0]);

   return 0;
}

int unimysql_fetch_lengths(int argc, struct descrip *argv) {
   MYSQL_RES *mysql_res;
   int i, n;
   unsigned long *lengths;

   if (argc < 1)
      return 101;
   if (!cnv_int(&argv[1], &argv[1])) {
      argv[0] = argv[1];
      return 101;
   }
   mysql_res = (MYSQL_RES*)IntVal(argv[1]);

   lengths = mysql_fetch_lengths(mysql_res);
   if (lengths == NULL) {
       return -1;
   }

   argv[0] = create_empty_list();
   n = mysql_num_fields(mysql_res);
   for (i = 0; i < n; ++i) {
       struct descrip tmp;
       MakeInt(lengths[i], &tmp);
       c_put(&argv[0], &tmp);
   }

   return 0;
}

int unimysql_fetch_row(int argc, struct descrip *argv) {
   MYSQL_RES *mysql_res;
   int i, n;
   unsigned long *lengths;
   MYSQL_ROW row;

   if (argc < 1)
      return 101;
   if (!cnv_int(&argv[1], &argv[1])) {
      argv[0] = argv[1];
      return 101;
   }
   mysql_res = (MYSQL_RES*)IntVal(argv[1]);

   row = mysql_fetch_row(mysql_res);
   if (row == NULL) {
       return -1;
   }

   lengths = mysql_fetch_lengths(mysql_res);
   if (lengths == NULL) {
       return -1;
   }

   argv[0] = create_empty_list();
   n = mysql_num_fields(mysql_res);
   for (i = 0; i < n; ++i) {
       struct descrip tmp = create_string2(row[i], lengths[i]);
       c_put(&argv[0], &tmp);
   }

   return 0;
}

int unimysql_row_seek(int argc, struct descrip *argv) {
   MYSQL_RES *mysql_res;
   MYSQL_ROW_OFFSET offset;

   if (argc < 1)
      return 101;
   if (!cnv_int(&argv[1], &argv[1])) {
      argv[0] = argv[1];
      return 101;
   }
   mysql_res = (MYSQL_RES*)IntVal(argv[1]);

   if (argc < 2)
       return 101;
   if (!cnv_int(&argv[2], &argv[2])) {
       argv[0] = argv[2];
       return 101;
   }
   offset = (MYSQL_ROW_OFFSET) IntVal(argv[2]);

   MakeInt(mysql_row_seek(mysql_res, offset), &argv[0]);

   return 0;
}

int unimysql_row_tell(int argc, struct descrip *argv) {
   MYSQL_RES *mysql_res;

   if (argc < 1)
      return 101;
   if (!cnv_int(&argv[1], &argv[1])) {
      argv[0] = argv[1];
      return 101;
   }
   mysql_res = (MYSQL_RES*)IntVal(argv[1]);

   MakeInt(mysql_row_tell(mysql_res), &argv[0]);

   return 0;
}

int unimysql_data_seek(int argc, struct descrip *argv) {
   MYSQL_RES *mysql_res;
   my_ulonglong offset;

   if (argc < 1)
      return 101;
   if (!cnv_int(&argv[1], &argv[1])) {
      argv[0] = argv[1];
      return 101;
   }
   mysql_res = (MYSQL_RES*)IntVal(argv[1]);

   if (argc < 2)
       return 101;
   if (!cnv_int(&argv[2], &argv[2])) {
       argv[0] = argv[2];
       return 101;
   }
   offset = (my_ulonglong) IntVal(argv[2]);

   mysql_data_seek(mysql_res, offset);

   return 0;
}

int unimysql_num_rows(int argc, struct descrip *argv) {
   MYSQL_RES *mysql_res;

   if (argc < 1)
      return 101;
   if (!cnv_int(&argv[1], &argv[1])) {
      argv[0] = argv[1];
      return 101;
   }
   mysql_res = (MYSQL_RES*)IntVal(argv[1]);

   MakeInt(mysql_num_rows(mysql_res), &argv[0]);

   return 0;
}

int unimysql_free_result(int argc, struct descrip *argv) {
   MYSQL_RES *mysql_res;

   if (argc < 1)
      return 101;
   if (!cnv_int(&argv[1], &argv[1])) {
      argv[0] = argv[1];
      return 101;
   }
   mysql_res = (MYSQL_RES*)IntVal(argv[1]);

   mysql_free_result(mysql_res);

   return 0;
}
