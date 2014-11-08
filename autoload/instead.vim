
" INSTEAD functions

" Function: instead#GrepInsteadObjects(obj) {{{1
function! instead#GrepInsteadObjects(obj) 
  
  " GrepInsteadObjects(obj)
  " Create location list with obj

  " Clear old location list
  call setloclist(0, [])
  " Grep all the lines into location list
  silent! exe 'lvimgrep /^\s*\w\{1,}\s*=\s*[ix]\{0,1}' . a:obj . '/j %'
  " If location list is not empty
  if !empty(getloclist(0))
    echo ""
    lwindow
    " Close llist on WinLeave
    au WinLeave <buffer> execute 'close!'
    " Map <Esc> to close llist
    nnoremap <buffer> <Esc> <C-w>w
    " Map configured keys inside buffer to corresponding
    " actions
    call instead#AddLocListMappings(g:InsteadRoomsKey, 
          \g:InsteadObjsKey, 
          \g:InsteadDlgsKey)
    " Map corresponding key to close llist
    if a:obj == g:InsteadRoomToken
      let l:closekey = g:InsteadRoomsKey
    elseif a:obj == g:InsteadObjToken
      let l:closekey = g:InsteadObjsKey
    elseif a:obj == g:InsteadDlgToken
      let l:closekey = g:InsteadDlgsKey
    else
      echo "Close key defining error!"
    endif
    " Map close key
    execute "nmap <buffer> " . l:closekey . " <C-w>w"
    " Checking window position
    if exists("g:InsteadWindowPosition")
      if g:InsteadWindowPosition == 'left'
        wincmd H
        vertical resize 28
      endif
    endif
    " fixwidth, nowrap
    setlocal winfixwidth
    setlocal nowrap
    " Get rid of junk in llist
    setlocal modifiable
    silent! exe 'g/.*/s/.*|\s*\(\w\{1,}\)\s*=.*/\1/g'
    setlocal nomodifiable
    " Go to top
    normal! gg
  else
    echo "No " . a:obj . "s in file."
  endif
endfunction " 1}}}

" Function: instead#OpenWindow(buffnr, lineno, searchword) {{{1
function! instead#OpenWindow(buffnr, lineno, searchword)
  
  " Temporary variable for exec string
  let execstring = 'sp Instead:'

  " Add position of opening window
  
  let execstring = execstring . a:buffnr . ":" . a:searchword
  exec execstring

  " Save original buffer number and current line
  let b:original_buffnr = a:buffnr
  let b:original_line = a:lineno

  " Disable swapfiles
  set noswapfile

  set modifiable
  normal! "zPGddgg
  set fde=getline(v:lnum)[0]=='L'
  set foldmethod=expr
  set foldlevel=0
  normal! zR

  " Resize line if too big.
  let l:hits = line("$")
  if l:hits < winheight(0)
    sil! exe "resize ".l:hits
  endif

  " Clean up.
  let @z = ""
  set nomodifiable

endfunction " 1}}} 

" Function: Search file {{{1
"--------------------------------------------------------------------------
function! instead#SearchFile(hits, word)
    " Search at the beginning and keep adding them to the register
    let l:match_count = 0
    normal! gg0
    let l:max = strlen(line('$'))
    let l:last_match = -1
    let l:div = 0
    while search('\(=\s*' . a:word . '\_s*{\)', "Wc") > 0
        let l:curr_line = line('.')
        if l:last_match == l:curr_line
            if l:curr_line == line('$')
                break
            endif
            normal! j0
            continue
        endif
        let l:last_match = l:curr_line
        if foldlevel(l:curr_line) != 0
            normal! 99zo
        endif
        if l:div == 0 
            if a:hits != 0
                let @z = @z."\n"
            endif
            let l:div = 1
        endif
        normal! 0
        let l:lineno = '     '.l:curr_line
        let @z = @z . strpart(l:lineno, strlen(l:lineno) - l:max).' '
        " add name
        let l:text = getline(".")
        let @z = @z . substitute(l:text, '^\s*\([a-zA-Z_-]*\)\s*=\s*' . a:word . '.*', '\1', '')
        let @z = @z . "\n"
        normal! $
        let l:match_count = l:match_count + 1
    endwhile
    return l:match_count
endfunction " 1}}}

" Function: Get line number {{{1
function! instead#LineNumber()
    let l:text = getline(".")
    if strlen(l:text) == 0
        return -1
    endif
    let l:num = matchstr(l:text, '[0-9]\+')
    if l:num == ''
        return -1
    endif
    return l:num
endfunction " 1}}}


" Function: Update document position {{{1
function! instead#UpdateDoc()
    let l:line_hit = instead#LineNumber()

    match none
    if l:line_hit == -1
        redraw
        return
    endif

    let l:buffnr = b:original_buffnr
    exe 'match Search /\%'.line(".").'l\w*\ze$/'
    if line(".") < (line("$") - (winheight(0) / 2)) + 1
        normal! zz
    endif
    execute bufwinnr(l:buffnr)." wincmd w"
    match none
    if l:line_hit == 0
        normal! 1G
    else
        exe "normal! ".l:line_hit."Gzz"
        exe 'match Search /\%'.line(".").'l.*/'
    endif
    execute bufwinnr('Instead:' . l:buffnr)." wincmd w"
    redraw
endfunction " 1}}

" Function: Clean up on exit {{{1

function! instead#Exit(key)

    call instead#UpdateDoc()
    match none

    let l:original_line = b:original_line
    let l:last_position = line('.')

    if a:key == -1
        nunmap <buffer> q
        nunmap <buffer> <cr>
        execute bufwinnr(b:original_buffnr)." wincmd w"
    else
        bd!
    endif

    let b:last_position = l:last_position

    if a:key == 0
        exe "normal! ".l:original_line."G"
    endif

    match none
    normal! zz

    execute "set updatetime=".s:old_updatetime
endfunction

" Function: Check for screen update {{{1
"--------------------------------------------------------------------------
function! instead#CheckForUpdate()
    if stridx(expand("%:t"), 'Instead:') == -1
        return
    endif
    if b:selected_line != line(".")
        call instead#UpdateDoc()
        let b:selected_line = line(".")
    endif
endfunction


" Function: Start the search. {{{1
"--------------------------------------------------------------------------
function! instead#GrepList(word)
    let l:original_buffnr = bufnr('%')
    let l:original_line = line(".")

    " last position
    if !exists('b:last_position')
        let b:last_position = 1
    endif
    let l:last_position = b:last_position


    " search file
    let l:index = 0
    let l:count = 0
    let l:hits = 0
    let l:search_word = a:word
    let l:hits = instead#SearchFile(l:hits, l:search_word)
    let l:count = l:count + l:hits

    " Make sure we at least have one hit.
    if l:count == 0
        echohl Search
        echo "instead.vim: No information found."
        echohl None
        execute 'normal! '.l:original_line.'G'
        return
    endif

    " display window
    call instead#OpenWindow(l:original_buffnr, l:original_line, a:word)

    " restore the cursor position
    if g:insteadRememberPosition != 0
        exec 'normal! '.l:last_position.'G'
    else
        normal! gg
    endif

    " Map exit keys
    nnoremap <buffer> <silent> q :call instead#Exit(0)<cr>
    nnoremap <buffer> <silent> <cr> :call instead#Exit(1)<cr>

    " Setup syntax highlight {{{
    syntax match tasklistFileDivider       /^File:.*$/
    syntax match tasklistLineNumber        /^\s*\d\+\s/

    highlight def link tasklistFileDivider  Title
    highlight def link tasklistLineNumber   LineNr
    highlight def link tasklistSearchWord   Search
    " }}}

    " Save globals and change updatetime
    let b:selected_line = line(".")
    let s:old_updatetime = &updatetime
    set updatetime=350

    " update the doc and hook the CheckForUpdate function.
    call instead#UpdateDoc()
    au! CursorHold <buffer> nested call instead#CheckForUpdate()

endfunction
"}}}


" Function: instead#InitGlobals(options) {{{1
" Initializes variables in dictionary
" "options" if they are not exists

function! instead#InitGlobals(options)
  if empty(a:options)
    return
  endif
  for variable in keys(a:options)
    if !exists(variable)
      execute "let " . variable . " = '" . a:options[variable] . "'"
    endif
  endfor
endfunction " 1}}}

" Function: instead#InitMappings(mappings) {{{1
" initializes mappings in "mappings" dictionary

function! instead#InitMappings(mappings)
  if empty(a:mappings)
    return
  endif
  for key in keys(a:mappings)
    execute 'nnoremap ' . eval(key) . ' :call instead#GrepInsteadObjects("' . eval(a:mappings[key]) . '")<CR>'
  endfor
endfunction

" 1}}}

" Function: instead#AddLocListMappings(...) {{{1
" Adds mappings to location list

function! instead#AddLocListMappings(...)
  if a:0 == 0
    return
  endif
  let index = 1
  while index <= a:0
    execute 'nmap <buffer> ' . a:{index} . ' :wincmd w<CR>' . a:{index}
    let index += 1
  endwhile
endfunction

"1}}}

" Function: instead#Init() {{{1
function! instead#Init()

  let options = {
        \ "g:InsteadRoomToken": "room",
        \ "g:InsteadObjToken" : "obj",
        \ "g:InsteadDlgToken" : "dlg",
        \ "g:InsteadRoomsKey" : "<F5>",
        \ "g:InsteadObjsKey"  : "<F6>",
        \ "g:InsteadDlgsKey"  : "<F7>",
        \ "g:InsteadRunKey"   : "<F8>",
        \}

  let mappings = {
        \ "g:InsteadRoomsKey": "g:InsteadRoomToken",
        \ "g:InsteadObjsKey" : "g:InsteadObjToken",
        \ "g:InsteadDlgsKey"  : "g:InsteadDlgToken",
        \}

  if !exists('g:tlRememberPosition')
    "   0 = Donot remember, find closest match
    let g:tlRememberPosition = 0
  endif

  command! InsteadRooms call instead#GrepList("room")
  command! InsteadObjs call instead#GrepList("obj")
  command! InsteadDlgs call instead#GrepList("dlg")

  if !exists('g:insteadWindowPosition')
    "   0 = Open at top
    let g:insteadWindowPosition = 0
  endif

  " Remember position
  "------------------------------------------------------------------------------
  if !exists('g:insteadRememberPosition')
    "   0 = Donot remember, find closest match
    let g:insteadRememberPosition = 0
  endif

  call instead#InitGlobals(options)
  call instead#InitMappings(mappings)

  " Dirty mapping for InsteadRun
  exec "nmap " . g:InsteadRunKey . " :InsteadRun<CR>"

endfunction
" 1}}}

" vim:foldmethod=marker
