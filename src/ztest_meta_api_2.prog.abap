*&---------------------------------------------------------------------*
*& Report ZTEST_META_API_2
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
REPORT ZTEST_META_API_2.


PARAMETERS: P_MOB TYPE STRING,
            P_TEXT TYPE STRING LOWER CASE.

 DATA: LV_JSON_PAYLOAD TYPE STRING.
 DATA: LV_TOKEN TYPE STRING.
 DATA: LV_RESPONSE TYPE STRING.
 DATA: LV_MSG TYPE STRING.

TYPES : BEGIN OF TP_TEXT,
        PREVIEW_URL TYPE STRING,
        BODY TYPE STRING,
END OF TP_TEXT.

TYPES : BEGIN OF TP_WHATSAPP_REQUEST,
        MESSAGING_PRODUCT TYPE STRING,
        RECIPIENT_TYPE    TYPE STRING,
        TO                TYPE STRING,
        TYPE              TYPE STRING,
        TEXT              TYPE TP_TEXT,
END OF TP_WHATSAPP_REQUEST.

TYPES: BEGIN OF TY_MESSAGE,
         ID             TYPE STRING,
         MESSAGE_STATUS TYPE STRING,
       END OF TY_MESSAGE.

TYPES: BEGIN OF TY_CONTACT,
        INPUT TYPE STRING,
        WA_ID TYPE STRING,
       END OF TY_CONTACT.

 TYPES: BEGIN OF TY_WHATSAPP_RESPONSE,
         MESSAGING_PRODUCT TYPE STRING,
         CONTACTS          TYPE STANDARD TABLE OF TY_CONTACT WITH EMPTY KEY,
         MESSAGES          TYPE STANDARD TABLE OF TY_MESSAGE WITH EMPTY KEY,
       END OF TY_WHATSAPP_RESPONSE.

DATA : LS_REQUEST TYPE TP_WHATSAPP_REQUEST.

DATA : LS_RESPONSE  TYPE TY_WHATSAPP_RESPONSE.

DATA: LV_URI TYPE STRING.

START-OF-SELECTION.

SELECT SINGLE * FROM ZWABA_CRED INTO @DATA(LS_WABA).

LV_URI = |https://graph.facebook.com/{ LS_WABA-VER }/{ LS_WABA-PHONEID }/messages|.

LS_REQUEST-MESSAGING_PRODUCT  = 'whatsapp'.
LS_REQUEST-RECIPIENT_TYPE     = 'individual'.
LS_REQUEST-TO                 = P_MOB.
LS_REQUEST-TYPE               = 'text'.

LS_REQUEST-TEXT-PREVIEW_URL      = 'false'.
LS_REQUEST-TEXT-BODY             = P_TEXT.

LV_JSON_PAYLOAD = /UI2/CL_JSON=>SERIALIZE( DATA        = LS_REQUEST
                                          COMPRESS    = ABAP_TRUE
                                          PRETTY_NAME = /UI2/CL_JSON=>PRETTY_MODE-LOW_CASE ).

CL_HTTP_CLIENT=>CREATE_BY_URL(
EXPORTING
  URL                = LV_URI                 " URL
  IMPORTING
    CLIENT             = DATA(LO_CLIENT)                 " HTTP Client Abstraction
  EXCEPTIONS
    ARGUMENT_NOT_FOUND = 1                " Communication parameter (host or service) not available
    PLUGIN_NOT_ACTIVE  = 2                " HTTP/HTTPS communication not available
    INTERNAL_ERROR     = 3                " Internal error (e.g. name too long)
    OTHERS             = 4
  ).
IF SY-SUBRC <> 0.

ENDIF.

LO_CLIENT->REQUEST->SET_HEADER_FIELD(
EXPORTING
  NAME  = 'Content-Type'                 " Name of the header field
  VALUE = 'application/json'                " HTTP header field value
  ).


LO_CLIENT->REQUEST->SET_HEADER_FIELD(
EXPORTING
  NAME  = 'Authorization'                 " Name of the header field
  VALUE = | Bearer { LS_WABA-ACCESS_TOKEN } |               " HTTP header field value
  ).

LO_CLIENT->REQUEST->SET_METHOD( 'POST' ).
LO_CLIENT->REQUEST->SET_CDATA( EXPORTING DATA = LV_JSON_PAYLOAD ).

LO_CLIENT->SEND(
  EXPORTING
    TIMEOUT                    = '60' " Timeout of Answer Waiting Time
  EXCEPTIONS
    HTTP_COMMUNICATION_FAILURE = 1                  " Communication Error
    HTTP_INVALID_STATE         = 2                  " Invalid state
    HTTP_PROCESSING_FAILED     = 3                  " Error When Processing Method
    HTTP_INVALID_TIMEOUT       = 4                  " Invalid Time Entry
    OTHERS                     = 5
).
IF SY-SUBRC <> 0.
WRITE: / 'Error during LO_CLIENT-SEND()'.
ENDIF.

LO_CLIENT->RECEIVE(
  EXCEPTIONS
    HTTP_COMMUNICATION_FAILURE = 1                " Communication Error
    HTTP_INVALID_STATE         = 2                " Invalid state
    HTTP_PROCESSING_FAILED     = 3                " Error When Processing Method
    OTHERS                     = 4
).
IF SY-SUBRC <> 0.
WRITE: / 'Problem in LO_CLIENT->RECEIVE() '.
ENDIF.

LO_CLIENT->RESPONSE->GET_STATUS(
  IMPORTING
    CODE   = DATA(LV_RES_CODE)                 " HTTP Status Code
    REASON = DATA(LV_RES_REASON)                 " HTTP status description
).

LV_RESPONSE = LO_CLIENT->RESPONSE->GET_CDATA( ).

IF LV_RES_CODE = 200.

  /UI2/CL_JSON=>DESERIALIZE(
    EXPORTING
      JSON             = LV_RESPONSE                 " JSON string
    CHANGING
      DATA             = LS_RESPONSE                 " Data to serialize
  ).

      IF LS_RESPONSE-MESSAGES[] IS NOT INITIAL.

      TRY.
      LV_MSG = LS_RESPONSE-MESSAGES[ 1 ]-ID.
      CATCH CX_ROOT.
      ENDTRY.
      ENDIF.

            CL_DEMO_OUTPUT=>DISPLAY_JSON( JSON = LV_RESPONSE  ).

  ELSE.
  DATA(LV_END_RES) = |RESPONSE CODE: { LV_RES_CODE }\n| &&
                     |REASON:        { LV_RES_REASON }\n| &&
                     |RESPONSE:      { LV_RESPONSE }\n|.


    CL_DEMO_OUTPUT=>DISPLAY(
      EXPORTING
        DATA = LV_END_RES                  " Text or Data
    ).

    ENDIF.
