#include "CouncisCurlTransport.h"

#include <curl/curl.h>
#include <pthread.h>
#include <stdio.h>
#include <string.h>

typedef struct {
    councis_curl_data_callback header_callback;
    councis_curl_data_callback body_callback;
    councis_curl_cancel_callback cancel_callback;
    void *context;
} councis_curl_callback_context;

static pthread_once_t councis_curl_once = PTHREAD_ONCE_INIT;

static void councis_curl_initialize(void) {
    (void)curl_global_init(CURL_GLOBAL_DEFAULT);
}

static size_t councis_curl_header_bridge(
    char *bytes,
    size_t size,
    size_t count,
    void *opaque) {
    councis_curl_callback_context *callbacks = opaque;
    size_t length = size * count;
    if (callbacks == NULL || callbacks->header_callback == NULL) {
        return length;
    }
    return callbacks->header_callback(
        (const uint8_t *)bytes,
        length,
        callbacks->context);
}

static size_t councis_curl_body_bridge(
    char *bytes,
    size_t size,
    size_t count,
    void *opaque) {
    councis_curl_callback_context *callbacks = opaque;
    size_t length = size * count;
    if (callbacks == NULL || callbacks->body_callback == NULL) {
        return length;
    }
    return callbacks->body_callback(
        (const uint8_t *)bytes,
        length,
        callbacks->context);
}

static int councis_curl_progress_bridge(
    void *opaque,
    curl_off_t download_total,
    curl_off_t download_current,
    curl_off_t upload_total,
    curl_off_t upload_current) {
    (void)download_total;
    (void)download_current;
    (void)upload_total;
    (void)upload_current;
    councis_curl_callback_context *callbacks = opaque;
    if (callbacks == NULL || callbacks->cancel_callback == NULL) {
        return 0;
    }
    return callbacks->cancel_callback(callbacks->context) != 0 ? 1 : 0;
}

static void councis_curl_copy_string(
    char *destination,
    size_t capacity,
    const char *source) {
    if (destination == NULL || capacity == 0) {
        return;
    }
    if (source == NULL) {
        destination[0] = '\0';
        return;
    }
    (void)snprintf(destination, capacity, "%s", source);
    destination[capacity - 1] = '\0';
}

int32_t councis_curl_perform(
    const councis_curl_request *request,
    councis_curl_data_callback header_callback,
    councis_curl_data_callback body_callback,
    councis_curl_cancel_callback cancel_callback,
    void *context,
    int64_t *status_code,
    char *primary_ip,
    size_t primary_ip_capacity,
    char *error_buffer,
    size_t error_buffer_capacity) {
    if (status_code != NULL) {
        *status_code = 0;
    }
    councis_curl_copy_string(primary_ip, primary_ip_capacity, NULL);
    councis_curl_copy_string(error_buffer, error_buffer_capacity, NULL);
    if (request == NULL || request->url == NULL || request->method == NULL) {
        return (int32_t)CURLE_BAD_FUNCTION_ARGUMENT;
    }

    (void)pthread_once(&councis_curl_once, councis_curl_initialize);
    CURL *easy = curl_easy_init();
    if (easy == NULL) {
        return (int32_t)CURLE_FAILED_INIT;
    }

    struct curl_slist *headers = NULL;
    struct curl_slist *resolve_entries = NULL;
    councis_curl_callback_context callbacks = {
        .header_callback = header_callback,
        .body_callback = body_callback,
        .cancel_callback = cancel_callback,
        .context = context,
    };
    char curl_error[CURL_ERROR_SIZE] = {0};
    CURLcode result = CURLE_OK;

#define COUNCIS_CURL_SET(option, value)                                      \
    do {                                                                     \
        result = curl_easy_setopt(easy, option, value);                      \
        if (result != CURLE_OK) {                                            \
            goto cleanup;                                                    \
        }                                                                    \
    } while (0)

    COUNCIS_CURL_SET(CURLOPT_URL, request->url);
    COUNCIS_CURL_SET(CURLOPT_NOSIGNAL, 1L);
    COUNCIS_CURL_SET(CURLOPT_FOLLOWLOCATION, 0L);
    COUNCIS_CURL_SET(CURLOPT_MAXREDIRS, 0L);
    COUNCIS_CURL_SET(CURLOPT_PROTOCOLS_STR, "http,https");
    COUNCIS_CURL_SET(CURLOPT_REDIR_PROTOCOLS_STR, "http,https");
    COUNCIS_CURL_SET(CURLOPT_SSL_VERIFYPEER, 1L);
    COUNCIS_CURL_SET(CURLOPT_SSL_VERIFYHOST, 2L);
    COUNCIS_CURL_SET(CURLOPT_HTTP_VERSION, CURL_HTTP_VERSION_2TLS);
    COUNCIS_CURL_SET(CURLOPT_ACCEPT_ENCODING, "");
    COUNCIS_CURL_SET(CURLOPT_TCP_KEEPALIVE, 1L);
    COUNCIS_CURL_SET(CURLOPT_ERRORBUFFER, curl_error);
    COUNCIS_CURL_SET(CURLOPT_HEADERFUNCTION, councis_curl_header_bridge);
    COUNCIS_CURL_SET(CURLOPT_HEADERDATA, &callbacks);
    COUNCIS_CURL_SET(CURLOPT_WRITEFUNCTION, councis_curl_body_bridge);
    COUNCIS_CURL_SET(CURLOPT_WRITEDATA, &callbacks);
    COUNCIS_CURL_SET(CURLOPT_XFERINFOFUNCTION, councis_curl_progress_bridge);
    COUNCIS_CURL_SET(CURLOPT_XFERINFODATA, &callbacks);
    COUNCIS_CURL_SET(CURLOPT_NOPROGRESS, 0L);
    COUNCIS_CURL_SET(CURLOPT_SUPPRESS_CONNECT_HEADERS, 1L);

    if (request->timeout_milliseconds > 0) {
        COUNCIS_CURL_SET(
            CURLOPT_TIMEOUT_MS,
            (long)request->timeout_milliseconds);
    }
    if (request->connect_timeout_milliseconds > 0) {
        COUNCIS_CURL_SET(
            CURLOPT_CONNECTTIMEOUT_MS,
            (long)request->connect_timeout_milliseconds);
    }
    if (request->direct_proxy != 0) {
        COUNCIS_CURL_SET(CURLOPT_PROXY, "");
        COUNCIS_CURL_SET(CURLOPT_NOPROXY, "*");
    }
    if (request->pinned_public_key != NULL) {
        COUNCIS_CURL_SET(
            CURLOPT_PINNEDPUBLICKEY,
            request->pinned_public_key);
    }

    for (size_t index = 0; index < request->header_count; index++) {
        if (request->headers[index] == NULL) {
            result = CURLE_BAD_FUNCTION_ARGUMENT;
            goto cleanup;
        }
        struct curl_slist *appended = curl_slist_append(
            headers,
            request->headers[index]);
        if (appended == NULL) {
            result = CURLE_OUT_OF_MEMORY;
            goto cleanup;
        }
        headers = appended;
    }
    {
        struct curl_slist *appended = curl_slist_append(
            headers,
            "Expect:");
        if (appended == NULL) {
            result = CURLE_OUT_OF_MEMORY;
            goto cleanup;
        }
        headers = appended;
    }
    if (headers == NULL) {
        result = CURLE_OUT_OF_MEMORY;
        goto cleanup;
    }
    COUNCIS_CURL_SET(CURLOPT_HTTPHEADER, headers);

    for (size_t index = 0;
         index < request->resolve_entry_count;
         index++) {
        if (request->resolve_entries[index] == NULL) {
            result = CURLE_BAD_FUNCTION_ARGUMENT;
            goto cleanup;
        }
        struct curl_slist *appended = curl_slist_append(
            resolve_entries,
            request->resolve_entries[index]);
        if (appended == NULL) {
            result = CURLE_OUT_OF_MEMORY;
            goto cleanup;
        }
        resolve_entries = appended;
    }
    if (resolve_entries != NULL) {
        COUNCIS_CURL_SET(CURLOPT_RESOLVE, resolve_entries);
    }

    if (strcmp(request->method, "GET") == 0) {
        COUNCIS_CURL_SET(CURLOPT_HTTPGET, 1L);
    } else if (strcmp(request->method, "POST") == 0) {
        COUNCIS_CURL_SET(CURLOPT_POST, 1L);
        COUNCIS_CURL_SET(
            CURLOPT_POSTFIELDS,
            request->body_length == 0
                ? ""
                : (const char *)request->body);
        COUNCIS_CURL_SET(
            CURLOPT_POSTFIELDSIZE_LARGE,
            (curl_off_t)request->body_length);
    } else {
        COUNCIS_CURL_SET(CURLOPT_CUSTOMREQUEST, request->method);
        if (request->body_length > 0) {
            COUNCIS_CURL_SET(
                CURLOPT_POSTFIELDS,
                (const char *)request->body);
            COUNCIS_CURL_SET(
                CURLOPT_POSTFIELDSIZE_LARGE,
                (curl_off_t)request->body_length);
        }
    }

    result = curl_easy_perform(easy);

    if (status_code != NULL) {
        long value = 0;
        if (curl_easy_getinfo(
                easy,
                CURLINFO_RESPONSE_CODE,
                &value) == CURLE_OK) {
            *status_code = (int64_t)value;
        }
    }
    {
        char *value = NULL;
        if (curl_easy_getinfo(
                easy,
                CURLINFO_PRIMARY_IP,
                &value) == CURLE_OK) {
            councis_curl_copy_string(
                primary_ip,
                primary_ip_capacity,
                value);
        }
    }

cleanup:
    if (curl_error[0] != '\0') {
        councis_curl_copy_string(
            error_buffer,
            error_buffer_capacity,
            curl_error);
    } else if (result != CURLE_OK) {
        councis_curl_copy_string(
            error_buffer,
            error_buffer_capacity,
            curl_easy_strerror(result));
    }
    if (resolve_entries != NULL) {
        curl_slist_free_all(resolve_entries);
    }
    if (headers != NULL) {
        curl_slist_free_all(headers);
    }
    curl_easy_cleanup(easy);
    return (int32_t)result;

#undef COUNCIS_CURL_SET
}

int32_t councis_curl_code_ssl_pinned_public_key_mismatch(void) {
    return (int32_t)CURLE_SSL_PINNEDPUBKEYNOTMATCH;
}
