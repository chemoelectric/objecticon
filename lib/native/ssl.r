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
       p->host = salloc(host);

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

function ssl_SslStream_connect(self)
   body {
       int rc;
       GetSelfSsl();
       if ((rc = SSL_connect(self_ssl->ssl)) <= 0) {
           whyf("SSL_connect: %s", ERR_error_string(SSL_get_error(self_ssl->ssl, rc), 0));
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
    int i, n;
 
    names = X509_get_ext_d2i(cert, NID_subject_alt_name, 0, 0);
    if (!names)
        return 0;
 
    n = sk_GENERAL_NAME_num(names);
    for(i = 0; i < n; ++i) {
        GENERAL_NAME *name = sk_GENERAL_NAME_value(names, i);
        if (name->type == GEN_DNS) {
            unsigned char *utf8;
            int res;
            ASN1_STRING_to_UTF8(&utf8, name->d.dNSName);
            res = pattern_match((char *)utf8, host);
            OPENSSL_free(utf8);
            if (res)
                return 1;
        }
    }
    return 0;
}

function ssl_SslStream_verify(self)
   body {
       long l;   
       X509 *peer;
       GetSelfSsl();

#if !MSWIN32
       if ((l = SSL_get_verify_result(self_ssl->ssl)) != X509_V_OK) {
           whyf("Certificate doesn't verify: %s", X509_verify_cert_error_string(l));
           fail;
       }
#endif

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
        * For now, assume we can read the full number of bytes.
        */
       MemProtect(s = alcstr(NULL, i));

       nread = SSL_read(self_ssl->ssl, s, i);
       if (nread <= 0) {
           /* Reset the memory just allocated */
           dealcstr(s);

           if (nread < 0 || SSL_get_error(self_ssl->ssl, nread) != SSL_ERROR_ZERO_RETURN) {
               whyf("SSL_read: %s", ERR_error_string(SSL_get_error(self_ssl->ssl, nread), 0));
               fail;
           } else   /* nread == 0 */
               return nulldesc;
       }

       /*
        * We may not have used the entire amount of storage we reserved.
        */
       dealcstr(s + nread);

       return string(nread, s);
   }
end

function ssl_SslStream_out(self, s)
   if !cnv:string(s) then
      runerr(103, s)
   body {
       word rc;
       GetSelfSsl();
       rc = SSL_write(self_ssl->ssl, StrLoc(s), StrLen(s));
       if (rc < 0 || (rc == 0 && SSL_get_error(self_ssl->ssl, rc) != SSL_ERROR_ZERO_RETURN)) {
           whyf("SSL_write: %s", ERR_error_string(SSL_get_error(self_ssl->ssl, rc), 0));
           fail;
       }
       return C_integer rc;
   }
end

function ssl_SslStream_shutdown(self)
   body {
       int rc;
       GetSelfSsl();
       rc = SSL_shutdown(self_ssl->ssl);
       if (rc < 0) {
           whyf("SSL_shutdown: %s", ERR_error_string(SSL_get_error(self_ssl->ssl, rc), 0));
           fail;
       }
       return self;
   }
end

function ssl_SslStream_close_impl(self)
   body {
       GetSelfSsl();
       SSL_set_quiet_shutdown(self_ssl->ssl, 1);
       SSL_shutdown(self_ssl->ssl);
       SSL_free(self_ssl->ssl);
       SSL_CTX_free(self_ssl->ctx);
       free(self_ssl->host);
       free(self_ssl);
       *self_ssl_dptr = nulldesc;
       return self;
   }
end
