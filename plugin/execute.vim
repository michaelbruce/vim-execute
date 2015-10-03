" vim-execute
" Author:       Michael Bruce <http://focalpointer.org/>
" Version:      0.1
"
" TODO use dispatch if available?
" TODO warn user if a packaging system is not available e.g lein repl/tmux
" TODO extract <Leader> y behaviour too (+ nvim behaviour)
" TODO check for tooling-force.jar with apex functions

" if exists('g:loaded_execute')
"   finish
" endif

let g:loaded_execute = 1

" Helpers {{{
fu! s:getterm()
  if has("nvim")
    return ':belowright 15split | term '
  else
    return ':!'
  endif
endf

function! s:movegitroot()
  cd %:p:h
  let gitdir=system("git rev-parse --show-toplevel")
  cd `=gitdir`
endf

fu! TmuxBuddy()
  " if vim has a stored pane id? (happens when creating new pane with SPCy)
  " open that pane below, otherwise create one and store it's Id
  " (further: check whether the pane exists...)

  " tmux display-message "#{window_id}" returns unique value for window
  " join-pane can use this e.g: join-pane -s @7
  " tmux can store variables e.g: temp_var='hello'
  " these are accessible via $temp_var
  " last_window_id="#{window_id}"; break-pane -d
  " behaviour is not quite right (last_pane_id seems to store before C-q call?)

  " opens a new pane below or reattaches the last.
  silent call system("tmux new-window")
  " target window/session (man tmux) session:window e.g home:1
endf

"}}}

" Execute {{{

fu! Execute()
  exec ':w'
  let term = s:getterm()

  if (&ft == 'ruby')
    let bundle_check=system("bundle exec --no-color ruby --version")
    if (match(bundle_check, 'Could not locate Gemfile') != -1)
      exec term . 'bundle exec ruby %'
    else
      exec term . 'ruby %'
    end
  elseif (&ft == 'rust')
    exec term . 'cargo run'
  elseif (&ft == 'python')
    exec term . 'python2 %'
  elseif (&ft == 'sh')
    exec term . './%'
  elseif (&ft == 'vim')
    exec ':so %'
    echo 'Vim Reloaded!'
  elseif (&ft == 'haskell')
    exec term . 'ghci %'
  elseif (&ft == 'visualforce.javascript.html' || &ft == 'apexcode')
    exec ':call ApexDeployCurrent()'
  elseif (&ft == 'java')
    exec '!javac %'
    exec '!java &:r'
  elseif (expand('%:e') == 'csv')
    exec ':s/\%x0d/\r<cr>:set nobomb<cr>:w ++enc=utf-8 %'
  else
    echo "I don't know how to use this filetype, sorry!"
  endif
endf

" }}}

" Test {{{1

function! Test()
  exec ':w'
  let term = s:getterm()

  if (&ft == 'javascript')
    exec term . 'npm test'
  elseif (&ft == 'python')
    exec term . 'python -m unittest %'
  elseif (&ft == 'java')
    exec term . 'java -cp .:/usr/share/java/junit.jar org.junit.runner.JUnitCore %'
  elseif (&ft == 'visualforce' || &ft == 'apexcode')
    exec ':ApexTest'
  elseif (&ft == 'vim')
    exec ':source %'
  elseif (&ft == 'cucumber')
    exec term . 'bundle exec cucumber %'
  else
    if !filereadable("Gemfile")
      exec ':cd  %:p:h'
      exec ':s:movegitroot()'
    end
    exec term . 'bundle exec rspec %'
  endif
endfunction

" }}}

" TestSingle {{{

function! TestSingle()
  exec ':w'
  if (&ft == 'apexcode')
    :normal! ?@isTest<cr>"sy0"ad/<C-r>s}<cr>"Addkmegg/class<cr>j<C-v>Gk,/'e2,/"ap
    exec ':ApexTest'
  elseif (&ft == 'ruby')
    let bundle_check=system("bundle exec --no-color ruby --version")
    if (match(bundle_check, 'Could not locate Gemfile') != -1)
      exec "!rspec %:" . line(".")
    else
      exec "!bundle exec rspec %:" . line(".")
    end
  else
    echo "I don't know how to run tests for this filetype, sorry!"
  endif
endfunction

" }}}

" Repl {{{

" TODO :g files, if no binding.pry etc (no breakpoints), launch individual
" repl, otherwise load program?

" pry only for now.
function! Repl()
  :normal! obinding.pry
  let term = s:getterm()
  exec ':w'
  if (&ft == 'ruby')
    let bundle_check=system("bundle exec --no-color ruby --version")
    if (match(bundle_check, 'Could not locate Gemfile') != -1)
      exec term . "pry %"
    else
      exec term . "bundle exec pry %"
    end
  else
    echo "I don't know how to deal with this filetype, sorry!"
  endif
endfunction

" }}}

" NeoVim & Tmux {{{1

if has("nvim")
  map <Leader>y :belowright 15split \| term<CR>

  " Alt + l is useful for escaping...
  imap <A-l> <esc>

  " <BS> == <C-h> currently
  map <BS> <C-\><C-n><C-w>h

  " Navigation from Terminal Mode
  tmap <A-l> <C-\><C-n>
  tmap <C-j> <C-\><C-n><C-w>j
  tmap <C-k> <C-\><C-n><C-w>k
  tmap <esc> <C-\><C-n>

else
  set cryptmethod=blowfish2 " most secure option available as of 7.4
  if len($TMUX) != 0

    map <Leader>y :silent !tmux splitw -v -p 25<CR>
    nnoremap <silent> <C-j> :call TmuxNavigate('j')<cr>
    nnoremap <silent> <C-k> :call TmuxNavigate('k')<cr>
  else
    map <Leader>y :echo "This isn't NeoVim, you can't do that here."<CR>
  endif
endif

function! VimNavigate(direction)
  try
    execute 'wincmd ' . a:direction
  catch
    echohl ErrorMsg | echo 'E11: Invalid in command-line window; <CR> executes, CTRL-C quits: wincmd k' | echohl None
  endtry
endfunction

" Copied from christoomey's vim-tmux-navigator
function! TmuxNavigate(direction)
  let nr = winnr()
  let tmux_last_pane = (a:direction == 'p' && s:tmux_is_last_pane)
  if !tmux_last_pane
    call VimNavigate(a:direction)
  endif
  " Forward the switch panes command to tmux if:
  " a) we're toggling between the last tmux pane;
  " b) we tried switching windows in vim but it didn't have effect.
  if tmux_last_pane || nr == winnr()
    let cmd = 'tmux select-pane -' . tr(a:direction, 'phjkl', 'lLDUR')
    silent call system(cmd)
    let s:tmux_is_last_pane = 1
  else
    let s:tmux_is_last_pane = 0
  endif
endfunction


" }}}1

command! Execute :call Execute()
command! Test :call Test()
command! TestSingle :call TestSingle()
command! Repl :call Repl()
command! G :call s:movegitroot()

" Code execution {{{1

function! ApexDeployCurrent()
  let term = s:getterm()
  let newFile = substitute(expand('%'), $HOME . 'Workspace/Singletrack-Core/SingletrackDev','','')
  exec ':!echo -e "' . newFile . '\n' . newFile . '-meta.xml" > /tmp/currentFile'
  exec term . 'java -jar ' . $HOME . '/dotfiles/tooling-force.com-0.3.4.0.jar
        \ --action=deploySpecificFiles
        \ --config=' . $HOME . '/notes/SingletrackDev.properties
        \ --projectPath=' . $HOME . '/Workspace/Singletrack-Core/SingletrackDev
        \ --responseFilePath=/tmp/responseFile
        \ --specificFiles=/tmp/currentFile
        \ --ignoreConflicts=true
        \ --pollWaitMillis=1000'
endfunction

" }}}1
