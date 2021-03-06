;+
; NAME:
;
;    cxml_ftp_get
;
; AUTHOR:
;
;    Yuguo Wu
;    irisksys@gmail.com
;
; PURPOSE:
;
;    Download cxml files from ftp/http website
;    remaining problems:
;      cannot check server update when remote_file_list not be set
;
; CALLING SEQUENCE:
;
;    result = cxml_ftp_get(ftp_server, remote_dir, remote_file_list = remote_file_list, $ 
;    local_dir = local_dir)
;
; ARGUMENTS:
;
;    ftp_server: A string of ftp server addresses
;    remote_dir: A string of remote directory in ftp server
;
; KEYWORDS:
;
;    remote_file_list: A string vector of download files. If it's given, program will download
;    files included in the list; otherwise, it will download all the files in the remote directory
;    local_dir: A string of local disk directory. If it's given, program will download files in it;
;    otherwise, program will download files in the folder of current IDL procedure file.
;
; OUTPUTS:
;
;    1：  Download successfully
;    0: Download unfinished because:
;      a. no update in ftp server, no need to download
;      b. no match files in ftp server
;
; EXAMPLE:
;
; MODIFICATION_HISTORY:
;
;    Yuguo Wu, irisksys@gmail.com, July 4th, 2011
;    Finished first version of program. Can operate a download task, without robustness
;    check
;    Yuguo Wu, irisksys@gmail.com, July 6th, 2011
;    Add remote file list selection, divide ftp server and remote dir into two arguments
;    and check ftp server update 
;    Yuguo Wu, irisksys@gmail.com, July 8th, 2011
;    Add recursive download and modified some files check
;
function check_update, remote_file_list, get_dir
  ; get all the local directory files
  local_file_list = file_search(get_dir, '*.xml')
  for i_local = 0, n_elements(local_file_list) - 1 do begin
    local_file_list[i_local] = strmid(local_file_list[i_local], strpos(local_file_list[i_local],$
    '\', /REVERSE_SEARCH)+1)
  endfor

  ; list files to be downloaded. Pass existed files
  flag_total_exist = 0
  for i_remote = 0, n_elements(remote_file_list) - 1 do begin
    flag_exist = 0
    for i_local = 0, n_elements(local_file_list) - 1 do begin
      if strcmp(remote_file_list[i_remote], local_file_list[i_local]) eq 1 then begin
        flag_exist = 1
        break
      endif
    endfor
    if flag_exist eq 1 then begin
      remote_file_list[i_remote] = 'null'
    endif else begin
      flag_total_exist =1
    endelse
  endfor
  if flag_total_exist eq 0 then return, ['0'] else begin
    remote_file_list = remote_file_list[where(strcmp(remote_file_list, 'null') eq 0)]
    return, remote_file_list
  endelse
end

function get_recursion, cxml_get, get_dir, remote_file_list
  cxml_get->GetProperty, URL_PATH = path
  origin_path = path
  
  ;test whether the link is a directory. If yes, enter into it; otherwise, download file 
  for i_list = 0, n_elements(remote_file_list) - 1 do begin
    if strpos(remote_file_list[i_list], 'xml') eq -1 then begin
      cxml_get->SetProperty, URL_PATH = path + remote_file_list[i_list]
      dir_next_level = cxml_get->GetFtpDirList()
      for i_next = 0, n_elements(dir_next_level) - 1 do begin
        dir_next_level[i_next] = strmid(dir_next_level[i_next], $
        strpos(dir_next_level[i_next], ' ', $
        /REVERSE_SEARCH)+1)
      endfor
      next_dir = get_dir + '\' + remote_file_list[i_list]
      if ~file_test(next_dir) then file_mkdir, next_dir else begin
        dir_next_level = check_update(dir_next_level, next_dir)
        if array_equal(dir_next_level, ['0']) eq 1 then continue 
      result = get_recursion(cxml_get, next_dir, dir_next_level)
      cxml_get->SetProperty, URL_PATH = origin_path
      endelse
    endif else begin
      cxml_get->SetProperty, URL_PATH = path + '/' + remote_file_list[i_list]
      cxml_file = cxml_get->Get(FILENAME = get_dir + '\' + remote_file_list[i_list])
      print, 'downloaded: ', cxml_file
    endelse
  endfor
end

function cxml_ftp_get, ftp_server, remote_dir, remote_file_list = remote_file_list, $ 
         local_dir = local_dir
  ; find or build local directory
  if keyword_set(local_dir) then begin
    root_dir = local_dir
    if ~file_test(root_dir) then file_mkdir, root_dir
  endif else begin
    root_dir = FILE_DIRNAME((ROUTINE_INFO('cxml_ftp_get', /FUNCTION, /SOURCE)).PATH)
  endelse
  ; no '\' in the end of given local directory, add it 
  if strcmp(strmid(root_dir, strlen(root_dir)-1), '\') eq 0 then root_dir = root_dir + '\'
  
  ; set ftp properties
  cxml_get = OBJ_NEW('IDLnetUrl')
  urlComponents = parse_url(ftp_server)
  cxml_get->SetProperty, URL_SCHEME = urlComponents.scheme
  cxml_get->SetProperty, URL_HOST = urlComponents.host
  cxml_get->SetProperty, URL_PATH = urlComponents.path + remote_dir
  cxml_get->SetProperty, URL_USERNAME = urlComponents.username
  cxml_get->SetProperty, URL_PASSWORD = urlComponents.password
  
  ; build directory for every ftp server downloading
  cxml_get->GetProperty, URL_HOST = host, URL_PATH = path
  get_dir = root_dir + host
  if ~file_test(get_dir) then file_mkdir, get_dir
            
  ; set remote download list
  get_list = cxml_get->GetFtpDirList()
  for i_list = 0, n_elements(get_list) - 1 do begin
      get_list[i_list] = strmid(get_list[i_list], strpos(get_list[i_list], ' ', $
      /REVERSE_SEARCH)+1)
  endfor
  ; no remote file list setting, download all the files in the server recursively
  if ~keyword_set(remote_file_list) then begin
    remote_file_list = get_list
    result = get_recursion(cxml_get, get_dir, remote_file_list)
  ; remote file list has been set, check the existence in the ftp server
  endif else begin
    for i_list = 0, n_elements(remote_file_list) - 1 do begin
      flag_match = 0
      for i_get_list = 0, n_elements(get_list) - 1 do begin
        if strcmp(remote_file_list[i_list], get_list[i_get_list]) eq 1 then begin
          flag_match = 1
          break
        endif
      endfor
      if flag_match eq 0 then begin
        print, 'File: ' + remote_file_list[i_list] + ' not exists'
        remote_file_list[i_list] = 'null'
      endif
    endfor

  ; if none of remote file list exists in the ftp server, continue to next ftp server
    flag_none_match = 0
    for i_list = 0, n_elements(remote_file_list) - 1 do begin
      if strcmp(remote_file_list[i_list],'null') eq 0 then begin
        flag_none_match = 1
        break
      endif
    endfor
    if flag_none_match eq 0 then begin
      print, 'No match file in the ftp server'
      return, 0 
    endif 
    remote_file_list = remote_file_list[where(strcmp(remote_file_list, 'null') eq 0)] 

  ; check if ftp server has been update. If hasn't, no need to download;otherwise, list
  ; download files that haven't been downloaded yet
    remote_file_list = check_update(remote_file_list, get_dir)
    if array_equal(remote_file_list, ['0']) then begin
      print, 'ftp server: ', host, ', no update'
      return, 0
    endif
   
  ; download cxml files
    for i_get = 0, n_elements(remote_file_list) - 1 do begin
      cxml_get->SetProperty, URL_PATH = remote_file_list[i_get]
      cxml_file = cxml_get->Get(FILENAME = get_dir + '\' + remote_file_list[i_get])
      print, 'downloaded: ', cxml_file
    endfor
  endelse
  OBJ_DESTROY, cxml_get
  return, 1
end