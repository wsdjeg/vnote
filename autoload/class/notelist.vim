" Class: class#notelist
" Author: lymslive
" Description: notelist manager
" Create: 2017-02-16
" Modify: 2017-03-15

"LOAD:
if exists('s:load') && !exists('g:DEBUG')
    finish
endif

" CLASS:
let s:class = class#old()
let s:class._name_ = 'class#notelist'
let s:class._version_ = 1

" which notebook this list belong to
let s:class.notebook = {}

" the argument of note-list
let s:class.argv = []

function! class#notelist#class() abort "{{{
    return s:class
endfunction "}}}

" NEW:
function! class#notelist#new(...) abort "{{{
    let l:obj = copy(s:class)
    call l:obj._new_(a:000)
    return l:obj
endfunction "}}}

" CTOR:
function! class#notelist#ctor(this, argv) abort "{{{
    if len(a:argv) > 0
        call a:this.SetNoteBook(a:argv[0])
    else
        echoerr 'expect a class#notebook to construct a class#notelist object'
    endif
    let a:this.argv = []
endfunction "}}}

" SetNoteBook: 
function! s:class.SetNoteBook(jNoteBook) dict abort "{{{
    if class#notebook#isobject(a:jNoteBook)
        let self.notebook = a:jNoteBook
        return 0
    else
        echoerr 'expect an object of class#notebook'
        return -1
    endif
endfunction "}}}

" RefreshList: Interface of NoteList command, fresh the notelist
function! s:class.RefreshList(argv) dict abort "{{{
    if a:argv ==# self.argv
        return 0
        :LOG 'directly redraw as same argv'
    endif
    let l:lsContent = self.GatherContent(a:argv)
    return self.RedrawContent(l:lsContent)
endfunction "}}}

" GatherContent: parse argv and then configue out list content
function! s:class.GatherContent(argv) dict abort "{{{
    " set option schema
    let l:jOption = class#cmdline#new('NoteList')
    call l:jOption.AddSingle('a', 'all', 'glob all notes')
    call l:jOption.AddSingle('d', 'date', 'note in this date')
    call l:jOption.AddSingle('t', 'tag', 'note has this tag')
    call l:jOption.AddSingle('D', 'Date-Tree', 'browse by date')
    call l:jOption.AddSingle('T', 'Tag-Tree', 'browse by tag')
    call l:jOption.AddSingle('m', 'mark', 'note in this mark default mru')
    call l:jOption.AddSingle('M', 'Mark-Tree', 'browse by mark or mru')
    " call l:jOption.AddDash('sepecial private tag -')

    " parser a:argv
    let l:iErr = l:jOption.ParseCheck(a:argv)
    if l:iErr != 0
        return []
    endif

    " let self.argv = a:argv
    let l:lsPostArgv = l:jOption.GetPost()

    " get the first argument
    let l:sArg = ''
    let l:iPostArgc = len(l:lsPostArgv)

    if l:iPostArgc > 0
        let l:sArg = l:lsPostArgv[0]
    endif

    " dispatch note-list mode
    let l:lsContent = []

    if l:jOption.Has('all')
        let l:lsContent = self.ListByDate('')
    elseif l:jOption.Has('Date-Tree')
        let l:lsContent = self.BrowseDate(l:sArg)
    elseif l:jOption.Has('Tag-Tree')
        let l:lsContent = self.BrowseTag(l:sArg)
    elseif l:jOption.Has('Mark-Tree')
        let l:lsContent = self.BrowseMark(l:sArg)
    elseif l:jOption.Has('date')
        if empty(l:sArg)
            let l:sArg = strftime("%Y/%m/%d")
        endif
        let l:lsContent = self.ListByDate(l:sArg)
    elseif l:jOption.Has('tag')
        let l:lsContent = self.ListByTag(l:sArg)
    elseif l:jOption.Has('mark')
        if empty(l:sArg)
            let l:lsContent = self.ListByMark('mru')
        else
            let l:lsContent = self.ListByMark(l:sArg)
        endif
    else
        if empty(l:sArg)
            let l:lsContent = self.ListByDate(strftime("%Y/%m/%d"))
        elseif l:sArg =~ self.notebook.pattern.dateYear
            let l:lsContent = self.ListByDate(l:sArg)
        else
            let l:lsContent = self.ListByTag(l:sArg)
        endif
    endif

    return l:lsContent
endfunction "}}}

" RedrawContent: update the notelist buffer
function! s:class.RedrawContent(lsContent) dict abort "{{{
    if expand('%:p') !=# self.notebook.GetListerName()
        execute 'edit ' . self.notebook.GetListerName()
        :ELOG 'try to write list content to non-lister buffer'
    endif

    setlocal modifiable
    " clear old content
    :1,$delet

    " set buffer content
    call setline(1, '$ NoteBook ' . self.notebook.basedir)
    call setline(2, '$ NoteList ' . join(self.argv))
    call setline(3, self.GetSepapateLine())
    call append(line('$'), a:lsContent)

    " put cursor
    normal! 4G
    let l:dConfig = vnote#GetConfig()
    let l:iPos = get(l:dConfig, 'list_default_cursor', 1)
    if l:iPos ==# '$'
        normal! G
    else
        let l:iDown = 0 + l:iPos - 1
        if l:iDown > 0
            execute 'normal! ' . l:iDown . 'j'
        endif
    endif

    " set type for new buffer
    if &filetype !=# 'notelist'
        set filetype=notelist
        set buftype=nofile
        setlocal bufhidden=hide
        setlocal noswapfile
    endif

    setlocal nomodifiable
    return 0
endfunction "}}}

" GetSepapateLine: 
function! s:class.GetSepapateLine() dict abort "{{{
    let l:len = 70
    if winwidth(0) < l:len
        let l:len = winwidth(0)
    endif
    return repeat('=', l:len)
endfunction "}}}

" AjustSeparateLine: 
function! s:class.AjustSeparateLine() dict abort "{{{
    if line('$') >= 3 && getline(3) =~ '^#\+'
        let l:sNewLine = self.GetSepapateLine()
        if len(l:sNewLine) != len(getline(3))
            setlocal modifiable
            call setline(3, l:sNewLine)
            setlocal nomodifiable
        endif
    endif
    return 0
endfunction "}}}

" ConvertEntry: return a note entry string from note file full path
function! s:class.ConvertEntry(pNoteFile) dict abort "{{{
    let l:jNote = class#note#new(a:pNoteFile)
    return l:jNote.GetNoteEntry()
endfunction "}}}

" ListByDate: note-list -d {yyyy[/mm/dd]}
" empty argument will glob all notes in notebook(try cache first)
function! s:class.ListByDate(sDatePath, ...) dict abort "{{{
    if empty(a:sDatePath)
        let self.argv = ['-a']
        let l:lpNoteFile = self.notebook.ReadCache()
        if empty(l:lpNoteFile)
            :DLOG 'cache empty, use glob to fetch all notes'
            let l:lpNoteFile = self.notebook.GlobNote(a:sDatePath)
            call map(l:lpNoteFile, 'self.ConvertEntry(v:val)')
        endif
    else
        let self.argv = ['-d', a:sDatePath]
        let l:lpNoteFile = self.notebook.GlobNote(a:sDatePath)
        call map(l:lpNoteFile, 'self.ConvertEntry(v:val)')
    endif
    return l:lpNoteFile
endfunction "}}}

" ListByTag: note-list -t {tag-name}
function! s:class.ListByTag(sTag, ...) dict abort "{{{
    let l:sTag = tolower(a:sTag)
    let self.argv = ['-t', l:sTag]

    let l:pDiretory = self.notebook.Tagdir()
    let l:pTagFile = l:pDiretory . '/' . l:sTag . '.tag'
    if filereadable(l:pTagFile)
        return readfile(l:pTagFile)
    else
        if l:sTag ==# '-'
            return self.notebook.GetPrivateNote()
        elseif l:sTag ==# '+'
            return self.notebook.GetPublicNote()
        else
            echo 'the notebook has no tag: ' . l:sTag
            return []
        endif
    endif
endfunction "}}}

" BrowseDate: note-list -D [yyyy/mm]
function! s:class.BrowseDate(ArgLead) dict abort "{{{
    " full yyyy/mm/dd date path
    if match(a:ArgLead, self.notebook.pattern.datePath) != -1
        return self.ListByDate(a:ArgLead)
    endif

    " partial yyyy/mm path
    let l:pDiretory = self.notebook.Datedir()
    if !empty(a:ArgLead) && a:ArgLead[-1] != '/'
        let l:ArgLead = a:ArgLead . '/'
    else
        let l:ArgLead = a:ArgLead
    endif

    let l:lpDate = glob(l:pDiretory . '/' . l:ArgLead . '*', 0, 1)
    let l:iHead = len(l:pDiretory) + 1
    call map(l:lpDate, 'strpart(v:val, l:iHead)')

    let self.argv = ['-D', a:ArgLead]
    return l:lpDate
endfunction "}}}

" BrowseTag: 
function! s:class.BrowseTag(ArgLead) dict abort "{{{
    let l:pDirectory = self.notebook.Tagdir()
    let l:ArgLead = tolower(a:ArgLead)

    " check browse a specific tag-file
    if !empty(l:ArgLead) && l:ArgLead[-1] != '/'
        let l:pTagFile = l:pDirectory . '/' . l:ArgLead . '.tag'
        if filereadable(l:pTagFile)
            return self.ListByTag(l:ArgLead)
        endif
    endif

    let self.argv = ['-T', l:ArgLead]
    return self.GlobTag_(l:pDirectory, l:ArgLead)
endfunction "}}}

" BrowseMark: 
function! s:class.BrowseMark(ArgLead) dict abort "{{{
    let l:pDirectory = self.notebook.Markdir()
    let l:ArgLead = tolower(a:ArgLead)

    " check browse a specific tag-file
    if !empty(l:ArgLead) && l:ArgLead[-1] != '/'
        let l:pTagFile = l:pDirectory . '/' . l:ArgLead . '.tag'
        if filereadable(l:pTagFile)
            return self.ListByMark(l:ArgLead)
        endif
    endif

    let self.argv = ['-M', l:ArgLead]
    return self.GlobTag_(l:pDirectory, l:ArgLead)
endfunction "}}}

" GlobTag: 
function! s:class.GlobTag_(pDirectory, ArgLead) dict abort "{{{
    let l:pDirectory = a:pDirectory
    let l:ArgLead = a:ArgLead

    let l:iHead = len(l:pDirectory) + 1
    let l:lpTag = glob(l:pDirectory . '/' . l:ArgLead . '*', 0, 1)
    call map(l:lpTag, 'strpart(v:val, l:iHead)')

    let l:lsRet = []
    let l:lsPath = []
    let l:lsLeaf = []
    for l:sTag in l:lpTag
        if l:sTag =~ '\.tag$'
            let l:sTag = substitute(l:sTag, '\.tag$', '', '')
            if l:sTag == '+'
                call add(l:lsRet, l:sTag)
            elseif l:sTag == '-'
                call add(l:lsRet, l:sTag)
            else
                call add(l:lsLeaf, l:sTag)
            endif
        else
            let l:sTag = l:sTag . '/'
            call add(l:lsPath, l:sTag)
        endif
    endfor

    if !empty(l:lsPath)
        call sort(l:lsPath)
        call extend(l:lsRet, l:lsPath)
    endif
    if !empty(l:lsLeaf)
        call sort(l:lsLeaf)
        call extend(l:lsRet, l:lsLeaf)
    endif

    return l:lsRet
endfunction "}}}

" ListByMark: bookmark and mru
function! s:class.ListByMark(sTag) dict abort "{{{
    let l:sTag = tolower(a:sTag)
    let self.argv = ['-m', l:sTag]

    let l:pDiretory = self.notebook.Markdir()
    let l:pTagFile = l:pDiretory . '/' . l:sTag . '.tag'
    if filereadable(l:pTagFile)
        if l:sTag ==# 'mru'
            let l:lpNoteFile = self.notebook.GetMruList()
            return l:lpNoteFile
        else
            return readfile(l:pTagFile)
        endif
    else
        return []
    endif

endfunction "}}}

" BackList: 
function! s:class.BackList() dict abort "{{{
    let l:cType = self.argv[0]
    let l:cType = substitute(l:cType, '^-', '', '')
    if stridx('TDMtdm', l:cType) < 0
        :LOG '[notelist] can only back in -DTdt modes'
        return -1
    endif

    let l:sArg = self.argv[1]
    if empty(l:sArg)
        :LOG '[notelist] alread in the top level'
        return 0
    endif

    let l:lsPath = split(l:sArg, '/')
    call remove(l:lsPath, -1)

    let l:lsArgv = [toupper(self.argv[0]), join(l:lsPath, '/')]
    call self.RefreshList(l:lsArgv)
    call search('^' . l:sArg, 'w')
endfunction "}}}

" LOAD:
let s:load = 1
:DLOG 'class#notelist is loading ...'
function! class#notelist#load(...) abort "{{{
    if a:0 > 0 && !empty(a:1) && exists('s:load')
        unlet s:load
        return 0
    endif
    return s:load
endfunction "}}}

" TEST:
function! class#notelist#test(...) abort "{{{
    return 0
endfunction "}}}
