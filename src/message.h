#ifndef _MESSAGE_H
#define _MESSAGE_H

#define MSG_MIME_HEADER  "Content-type: "

#if defined(_WIN32) || defined(__EMX__)
#define CRLF "\n"
#else
#define CRLF "\r\n"
#endif

#endif /* _MESSAGE_H */
