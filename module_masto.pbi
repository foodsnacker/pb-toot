;{ ===========================================================================================================[Header ]
;: 
;: Name ......... : MastoToot
;: Version ...... : 1.1.0
;: Type ......... : Module
;: Author ....... : jamirokwai
;: Compiler ..... : PureBasic V6.01
;: Subsystem .... : none
;: TargetOS ..... : Windows ? / MacOS / Linux ?
;: Description .. : Toot to Mastodon server
;: License ...... : MIT License 
;: 
;: Thanks to: https://chrisjones.io/articles/using-php-And-curl-To-post-media-To-the-mastodon-api/
;:
;: Permission is hereby granted, free of charge, to any person obtaining a copy
;: of this software and associated documentation files (the "Software"), to deal
;: in the Software without restriction, including without limitation the rights
;: to use, copy, modify, merge, publish, distribute, sublicense, And/Or sell
;: copies of the Software, and to permit persons to whom the Software is
;: furnished to do so, subject to the following conditions:
;:  
;: The above copyright notice and this permission notice shall be included in all
;: copies or substantial portions of the Software.
;: 
;: THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
;: IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
;: FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
;: AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
;: LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
;: OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
;: SOFTWARE. 
;:
;}

DeclareModule MastoToot
  
  Global masto_appname.s   ; the name of your app, e.g. "PureBasic"
  Global masto_appweb.s    ; the URL of your app, e.g. "https://www.purebasic.com"
  Global masto_server.s    ; the URL of the server, e.g. "https://mastodon.gamedev.place"
  Global masto_reply.s     ; will be the return value
  Global access_token.s    ; your access token. You should let your users generate it and place it in the app!
  
  Declare   InitMasto(appserver.s, appname.s, appweb.s)
  Declare   SetAccessToken(token.s)
  Declare   VerifyAccessToken()
  Declare.s AddMedia(filename.s, *source, buffersize, imagetype.s, description.s = "") ; with filetype = "png" or "jpeg"
  Declare.s Toot(message.s, imageid.s = "")
  
EndDeclareModule

Module MastoToot
  EnableExplicit
  
  Define masto_request_create_application.s
  Define masto_request_create_authenticate.s
  Define masto_verify_credentials.s
  
  Global masto_create_application_api.s
  Global masto_request_authenticate_api.s
  Global masto_verify_credentials_api.s
  Global masto_toot_api.s
  Global masto_media_api.s
  
  Define client_id.s
  Define client_secret.s
  Define vapid_key.s     
  
  Procedure   InitMasto(appserver.s, appname.s, appweb.s)
    masto_appname = appname 
    masto_appweb  = appweb
    masto_server  = appserver
    
    masto_create_application_api   = masto_server + "/api/v1/apps"
    masto_request_authenticate_api = masto_server + "/oauth/token"
    masto_verify_credentials_api   = masto_server + "/api/v1/apps/verify_credentials"
    masto_toot_api                 = masto_server + "/api/v1/statuses"
    masto_media_api.s              = masto_server + "/api/v2/media"
  EndProcedure
  
  Procedure   SetAccessToken(token.s)
    access_token = token
  EndProcedure
  
  Procedure.s GenerateCreateApplicationRequest(clientname.s, appweb.s)
    ProcedureReturn "client_name=" + clientname + "&redirect_uris=urn:ietf:wg:oauth:2.0:oob&scopes=Read write push&website=" + appweb
  EndProcedure
  
  Procedure.s GenerateCreateAuthenticate(clientid.s, clientsecret.s)
    ProcedureReturn "client_id=" + clientid + "&client_secret=" + clientsecret + "&redirect_uri=urn:ietf:wg:oauth:2.0:oob&grant_type=client_credentials"
  EndProcedure
  
  Procedure.s GetPartFromString(instring.s, whatstring.s)
    Define first = FindString(instring, whatstring) + Len(whatstring) + 3
    If first > 0
      Define second = FindString(instring, Chr(34), first)
      ProcedureReturn Mid(instring, first, second - first)
    EndIf
    ProcedureReturn "1"
  EndProcedure
  
  Procedure.s CallServerPost(serverurl.s, servercall.s)
    Define result.s = ""
    
    Define *Buffer = AllocateMemory(Len(servercall), #PB_Memory_NoClear)
    PokeS(*Buffer, servercall, -1, #PB_UTF8|#PB_String_NoZero)
    
    Define HttpRequest = HTTPRequestMemory(#PB_HTTP_Post, serverurl, *Buffer, MemorySize(*Buffer))
    
    If HttpRequest
      masto_reply = HTTPInfo(HTTPRequest, #PB_HTTP_Response)
      result      = HTTPInfo(HTTPRequest, #PB_HTTP_StatusCode)
      FinishHTTP(HTTPRequest)
    EndIf
    
    FreeMemory(*buffer)
    
    ProcedureReturn result
  EndProcedure
  
  Procedure.s CallServerPost_Verify(serverurl.s, servercall.s, accesstoken.s)
    Define result.s = ""
    
    Define *Buffer = AllocateMemory(Len(servercall), #PB_Memory_NoClear)
    PokeS(*Buffer, servercall, -1, #PB_UTF8|#PB_String_NoZero)
    
    Define NewMap header.s()
    header("Authorization") = "Bearer " + accesstoken
    Define HttpRequest = HTTPRequestMemory(#PB_HTTP_Get, serverurl, *Buffer, MemorySize(*Buffer), 0, Header())
    
    If HttpRequest
      masto_reply = HTTPInfo(HTTPRequest, #PB_HTTP_Response)
      result      = HTTPInfo(HTTPRequest, #PB_HTTP_StatusCode)
      
      FinishHTTP(HTTPRequest)
    EndIf
    
    FreeMemory(*buffer)
    
    ProcedureReturn result
  EndProcedure
  
  Procedure.s AddMedia(filename.s, *source, buffersize, imagetype.s, description.s = "")
    Define mediaid.s
    Define boundary.s = "------0123456789"
    
    Define NewMap header.s()
    
    Define post_data.s = "--" + boundary + #CRLF$
    post_data + "Content-Disposition: form-data; name=" + Chr(34) + "file" + Chr(34) + "; " +
                "filename=" + Chr(34) + GetFilePart(filename) + Chr(34)
    If description <> ""
      post_data + ";description=" + Chr(34) + description + Chr(34)
    EndIf
    post_data + #CRLF$
    
    post_data + "Content-Type: image/" + imagetype + #CRLF$
    post_data + #CRLF$
    
    Global PostLen = StringByteLength(post_data, #PB_UTF8)
    Global BoundaryLen = StringByteLength(boundary, #PB_UTF8)
    
    Global *Buffer = AllocateMemory(PostLen + buffersize + 2 + 2 + BoundaryLen + 2 + 2, #PB_Memory_NoClear)
    PokeS(*Buffer, post_data, -1, #PB_UTF8|#PB_String_NoZero)
    CopyMemory(*source, *buffer + PostLen, buffersize)
    PokeS(*Buffer + PostLen + buffersize, #CRLF$ + "--" + boundary + "--" + #CRLF$, -1, #PB_UTF8|#PB_String_NoZero)
    
    header("Content-Type") = "multipart/form-data; boundary=" + boundary
    header("Content-Length") = Str(MemorySize(*Buffer))
    header("Authorization") = "Bearer " + access_token
    
    Global HttpRequest = HTTPRequestMemory(#PB_HTTP_Post, masto_media_api, *Buffer, MemorySize(*Buffer), 0, Header())
    If HttpRequest
      masto_reply = HTTPInfo(HTTPRequest, #PB_HTTP_StatusCode)
      
      If masto_reply <> "200"
        FinishHTTP(HTTPRequest)
        ProcedureReturn "0"
      EndIf
      
      Define response.s = HTTPInfo(HTTPRequest, #PB_HTTP_Response)
      Debug response
      
      mediaid = GetPartFromString(response, "id")
      
      FinishHTTP(HttpRequest)
    EndIf
    
    FreeMemory(*Buffer)
    ProcedureReturn mediaid
  EndProcedure
  
  Procedure.s Toot(message.s, imageid.s = "")
    Define result.s = ""
    
    message = "status=" + message
    
    If imageid <> ""
      message + "&media_ids[]=" + imageid
    EndIf
    
    Define NewMap header.s()
    header("Authorization") = "Bearer " + access_token
    HttpRequest = HTTPRequest(#PB_HTTP_Post, masto_toot_api, message, 0, Header())
    
    If HttpRequest
      masto_reply = HTTPInfo(HTTPRequest, #PB_HTTP_Response)
      If masto_reply <> "200"
        FinishHTTP(HTTPRequest)
        ProcedureReturn "0"
      EndIf
      result      = HTTPInfo(HTTPRequest, #PB_HTTP_StatusCode)
      FinishHTTP(HTTPRequest)
    EndIf
    
    ProcedureReturn result
  EndProcedure
  
  ; you won't need these procedures, but if you like to create an application on your server,
  ; or get keys, and your personal access token, go for it. I would recommend to ask people to open their
  ; account on their server, and generate the token by themselves.
  Procedure   RegisterApplication() ; if you do, call this in step 1 and save the keys
                                    ; register application: don't do it in the app. Let users supply only the access_token
                                    ; masto_request_create_application.s = GenerateCreateApplicationRequest(masto_appname, masto_appweb)
                                    ; CallServerPost(masto_api, masto_request_create_application)
    
    ; get all keys
    ; client_id     = GetPartFromString(masto_reply, "client_id")
    ; client_secret = GetPartFromString(masto_reply, "client_secret")
    ; vapid_key     = GetPartFromString(masto_reply, "vapid_key")    
  EndProcedure
  
  Procedure   RequestAuthorizationForToken() ; if you do, call this in step 2
                                             ; request authentication
                                             ; masto_request_create_authenticate.s = GenerateCreateAuthenticate(client_id, client_secret)
                                             ; CallServerPost(masto_request_authenticate_api, masto_request_create_authenticate)
    
    ;- get access-token
    ; Define access_token.s  = GetPartFromString(masto_reply, "access_token")
    
  EndProcedure
  
  ; this on may be helpful to check, if users have correctly entered access-token and server
  Procedure   VerifyAccessToken() ; if you do, call this in step 3 to verify access and the token from step 2
    CallServerPost_Verify(masto_verify_credentials_api, " ", access_token)    
    If GetPartFromString(masto_reply, "name") = masto_appname ; the app-name will be returned
      ProcedureReturn #True
    Else
      ProcedureReturn #False
    EndIf
  EndProcedure
  
EndModule

CompilerIf #PB_Compiler_IsMainFile
  UsePNGImageEncoder()
  
  #masto_server      = "my-mastodon-server"
  #masto_appname     = "my-app"
  #masto_app_url     = "page-of-my-app"
  #masto_acces_token = "my-token" ; from my/server/settings/applications
  MastoToot::InitMasto(#masto_server, #masto_appname, #masto_app_url)
  MastoToot::SetAccessToken(#masto_acces_token)
  If MastoToot::VerifyAccessToken() = #True
    
    ; creates a black image
    CreateImage(0,400,400,32,0)
    Define *buff = EncodeImage(0, #PB_ImagePlugin_PNG)
    
    ; add media to your mastodon account
    Define media_id.s = MastoToot::AddMedia("filename.png", *buff, MemorySize(*buff), "png", "Black image.")
    
    ; toot it with one image
    MastoToot::Toot("Tooting from PureBasic!", media_id)
  EndIf
CompilerEndIf
