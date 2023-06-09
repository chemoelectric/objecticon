#passthru #undef code
#passthru #include <openssl/ssl.h>
#passthru #include <openssl/err.h>
#passthru #include <openssl/x509v3.h>

struct sslstream {
    SSL_CTX *ctx;
    SSL *ssl;
    char *host;
};

#begdef GetSelfSsl()
struct sslstream *self_ssl;
dptr self_ssl_dptr;
static struct inline_field_cache self_ssl_ic;
self_ssl_dptr = c_get_instance_data(&self, (dptr)&ptrf, &self_ssl_ic);
if (!self_ssl_dptr)
    syserr("Missing ptr field");
if (is:null(*self_ssl_dptr))
    runerr(219, self);
self_ssl = (struct sslstream*)IntVal(*self_ssl_dptr);
#enddef

static int pattern_match (char *pattern, char *string)
{
    char *p = pattern, *n = string;
    char c;
    for (; (c = oi_tolower((*p++))) != '\0'; n++)
        if (c == '*')
        {
            for (c = oi_tolower((*p)); c == '*'; c = oi_tolower((*++p)))
                ;
            for (; *n != '\0'; n++)
                if (oi_tolower((*n)) == c && pattern_match (p, n))
                    return 1;
                else if (*n == '.')
                    return 0;
            return c == '\0';
        }
        else
        {
            if (c != oi_tolower((*n)))
                return 0;
        }
    return *n == '\0';
}

static char *rm_trailing_dot(char *s)
{
    size_t n = strlen(s);
    if (n > 0 && s[n - 1] == '.')
        s[n - 1] = 0;
    return s;
}

function ssl_SslStream_new_impl(other, host)
   if !cnv:C_string(host) then
      runerr(103, host)
   body {
       struct sslstream *p;
       SSL_METHOD *meth;
       SSL_CTX *ctx;
       SSL *ssl;
       BIO *sbio;
#if MSWIN32
       SocketStaticParam(other, fd);
#else
       FdStaticParam(other, fd);
#endif

       SSL_library_init();
       SSL_load_error_strings();

       /* Create our context*/
       meth = (SSL_METHOD *)SSLv23_client_method();
       ctx = SSL_CTX_new(meth);

       p = safe_malloc(sizeof(*p));
       p->ctx = ctx;
       /* A trailing dot in the hostname must be removed, or the
        * certificate may not match. (See RFC 6066 page 7). */
       p->host = rm_trailing_dot(salloc(host));

       SSL_CTX_set_default_verify_paths(ctx);

       /* Connect the SSL socket */
       ssl = SSL_new(ctx);
       sbio = BIO_new_socket(fd, BIO_NOCLOSE);
       SSL_set_bio(ssl, sbio, sbio);
       SSL_set_tlsext_host_name(ssl, p->host);

       p->ssl = ssl;

       return C_integer((word)p);
   }
end

static void io_set_whyf(struct sslstream *ss, char *fun, int rc)
{
    int se;
    se = SSL_get_error(ss->ssl, rc);
    if (se == SSL_ERROR_SYSCALL || se == SSL_ERROR_SSL)
        whyf("%s: %s (SSL_get_error=%d)", fun, ERR_error_string(ERR_peek_last_error(), 0), se);
    else
        whyf("%s: SSL error (SSL_get_error=%d)", fun, se);
}

function ssl_SslStream_connect(self)
   body {
       int rc;
       GetSelfSsl();
       SigPipeProtect(rc = SSL_connect(self_ssl->ssl));
       if (rc <= 0) {
           io_set_whyf(self_ssl, "SSL_connect", rc);
           fail;
       }
       return self;
   }
end

/* See:- http://therning.org/magnus/archives/812 */

static int match_common_name(X509 *cert, char *host)
{
    X509_NAME *subj_name;
    int index, res;
    X509_NAME_ENTRY *entry;
    ASN1_STRING *entry_data;
    unsigned char *utf8;
 
    subj_name = X509_get_subject_name(cert);
    if (!subj_name)
        return 0;
 
    index = X509_NAME_get_index_by_NID(subj_name, NID_commonName, -1);
    entry = X509_NAME_get_entry(subj_name, index);
    entry_data = X509_NAME_ENTRY_get_data(entry);
    ASN1_STRING_to_UTF8(&utf8, entry_data);
    res = pattern_match((char *)utf8, host);
    OPENSSL_free(utf8);
    return res;
}

static int match_alt_names(X509 *cert, char *host)
{
    GENERAL_NAMES *names;
    int i, n, res;
 
    names = X509_get_ext_d2i(cert, NID_subject_alt_name, 0, 0);
    if (!names)
        return 0;

    n = sk_GENERAL_NAME_num(names);
    for(i = 0; i < n; ++i) {
        GENERAL_NAME *name = sk_GENERAL_NAME_value(names, i);
        switch (name->type) {
            case GEN_DNS: {
                unsigned char *utf8;
                if (ASN1_STRING_to_UTF8(&utf8, name->d.dNSName) >= 0) {
                    res = pattern_match((char *)utf8, host);
                    OPENSSL_free(utf8);
                    if (res)
                        return 1;
                }
                break;
            }
            case GEN_IPADD: {
                ASN1_OCTET_STRING *t = a2i_IPADDRESS(host);
                if (t) {
                    res = (ASN1_STRING_cmp(t, name->d.iPAddress) == 0);
                    ASN1_OCTET_STRING_free(t);
                    if (res)
                        return 1;
                }
                break;
            }
        }
    }
    return 0;
}

function ssl_SslStream_verify(self)
   body {
       long l;   
       X509 *peer;
       GetSelfSsl();

       if ((l = SSL_get_verify_result(self_ssl->ssl)) != X509_V_OK) {
           whyf("Certificate doesn't verify: %s", X509_verify_cert_error_string(l));
           fail;
       }

       peer = SSL_get_peer_certificate(self_ssl->ssl);
       if (!match_common_name(peer, self_ssl->host) && !match_alt_names(peer, self_ssl->host)) {
           LitWhy("Couldn't match host name with certificate's common name or alternate names");
           fail;
       }
       return self;
   }
end

function ssl_SslStream_in(self, i)
   if !cnv:C_integer(i) then
      runerr(101, i)
   body {
       word nread;
       char *s;
       GetSelfSsl();

       if (i <= 0)
           Irunerr(205, i);

       /*
        * Reserve the full number of bytes.
        */
       MemProtect(s = reserve(Strings, i));

       SigPipeProtect(nread = SSL_read(self_ssl->ssl, s, i));
       if (nread <= 0) {
           if (nread < 0 || SSL_get_error(self_ssl->ssl, nread) != SSL_ERROR_ZERO_RETURN) {
               io_set_whyf(self_ssl, "SSL_read", nread);
               fail;
           } else   /* nread == 0 */
               return nulldesc;
       }

       /*
        * Confirm the allocation actually required.
        */
       alcstr(NULL, nread);

       return string(nread, s);
   }
end

function ssl_SslStream_out(self, s)
   if !cnv:string(s) then
      runerr(103, s)
   body {
       word rc;
       GetSelfSsl();
       /*
        * Calling SSL_write with a length of 0 is invalid; so for
        * consistency with other streams, make this a no-op and return
        * 0.
        */
       if (StrLen(s) == 0)
           rc = 0;
       else {
           SigPipeProtect(rc = SSL_write(self_ssl->ssl, StrLoc(s), StrLen(s)));
           if (rc <= 0) {
               io_set_whyf(self_ssl, "SSL_write", rc);
               fail;
           }
       }
       return C_integer rc;
   }
end

function ssl_SslStream_shutdown(self, full)
   body {
       int rc;
       GetSelfSsl();
       if (!is_flag(&full))
          runerr(171, full);
       do {
           SigPipeProtect(rc = SSL_shutdown(self_ssl->ssl));
       } while (rc == 0 && !is:null(full));
       if (rc < 0) {
           io_set_whyf(self_ssl, "SSL_shutdown", rc);
           fail;
       }
       return self;
   }
end

function ssl_SslStream_close_impl(self)
   body {
       GetSelfSsl();
       SSL_free(self_ssl->ssl);
       SSL_CTX_free(self_ssl->ctx);
       free(self_ssl->host);
       free(self_ssl);
       *self_ssl_dptr = nulldesc;
       return self;
   }
end
