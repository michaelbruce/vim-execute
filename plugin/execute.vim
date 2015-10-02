" vim-execute
" Author:       Michael Bruce <http://focalpointer.org/>
" Version:      0.1
"
" TODO use dispatch if available?
" TODO warn user if a packaging system is not available e.g lein repl/tmux

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
}}}

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
  else
    echo "I don't know how to use this filetype, sorry!"
  endif
endf
"

command! Execute :call Execute()
