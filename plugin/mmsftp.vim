
" Title: mmsftp
" Description: Upload and download files through sftp
" Usage: :Hupload and :Hdownload
"        See README for more
" Github: https://github.com/mmansano/vim-mmsftp
" Author: Marcelo Mansano
" License: MIT

function! mmsftp#find_config_file()
	let l:configpath = expand('%:p:h')
	let l:configfile = l:configpath . '/.hsftp'
	let l:foundconfig = ''
	if filereadable(l:configfile)
		let l:foundconfig = l:configfile
	else
		while !filereadable(l:configfile)
			let slashindex = strridx(l:configpath, '/')
			if slashindex >= 0
				let l:configpath = l:configpath[0:slashindex]
				let l:configfile = l:configpath . '.hsftp'
				let l:configpath = l:configpath[0:slashindex-1]
				if filereadable(l:configfile)
					let l:foundconfig = l:configfile
					break
				endif
				if slashindex == 0 && !filereadable(l:configfile)
					break
				endif
			else
				break
			endif
		endwhile
	endif

	return l:foundconfig
endfunction

function! mmsftp#is_enabled()
	if strlen(mmsftp#find_config_file()) > 0
		return 1
	else
		return 0
	endif
endfunction

function! mmsftp#load_config()
	let conf = {}
	let l:config_path = mmsftp#find_config_file()

	if strlen(l:config_path) > 0
		let options = readfile(l:config_path)
		for i in options
			let vname = substitute(i[0:stridx(i, ' ')], '^\s*\(.\{-}\)\s*$', '\1', '')
			let vvalue = escape(substitute(i[stridx(i, ' '):], '^\s*\(.\{-}\)\s*$', '\1', ''), "%#!")
			let conf[vname] = vvalue
		endfor

		let conf['local'] = fnamemodify(l:config_path, ':h:p') . '/'
	endif

	return conf
endfunction

if !exists('g:mmsftp#config')
	let g:mmsftp#prompt = 'mmsftp => '
	let g:mmsftp#command = 'scp'
	let g:mmsftp#config = mmsftp#load_config()
	if has_key(g:mmsftp#config, 'upload_on_save')
		if g:mmsftp#config['upload_on_save'] == 1
			augroup mmsftp#upload_on_save
				au!
				au BufWritePost * call mmsftp#upload_on_save()
			augroup END
		else
			augroup mmsftp#upload_on_save
				au!
			augroup END
			augroup! mmsftp#upload_on_save
		endif
	endif
endif

function! mmsftp#warning_message(msg)
	echohl WarningMsg | !echo g:mmsftp#prompt . a:msg | !echohl None
endfunction

function! mmsftp#info_message(msg)
	echo g:mmsftp#prompt . a:msg 
endfunction

function! mmsftp#get_local_path()
	return expand('%:p')
endfunction

function! mmsftp#get_remote_path()
	let localpath = mmsftp#get_local_path()
	return g:mmsftp#config['remote'] . localpath[strlen(g:mmsftp#config['local']):]
endfunction

function! mmsftp#finished_cb(channel)
	mmsftp#info_message('Done!')
endfunction

function! mmsftp#on_upload_cb(job_id, data, event) dict
	if a:event == 'stderr'
		call mmsftp#warning_message('Upload error ')
	else
		call mmsftp#info_message('Upload finished')
	endif
endfunction

function! mmsftp#diff_remote()
	if mmsftp#is_enabled() && has_key(g:mmsftp#config, 'host')
		let remotepath = mmsftp#get_remote_path()
		let cmd = printf('diffsplit scp://%s@%s/%s|windo wincmd H', g:mmsftp#config['user'], g:mmsftp#config['host'], remotepath)
		silent execute cmd
	endif
endfunction

function! mmsftp#download_file()
	if mmsftp#is_enabled() && has_key(g:mmsftp#config, 'host')
		let remotepath = mmsftp#get_remote_path()
		let cmd = printf('1,$d|0Nr "sftp://%s@%s/%s"', g:mmsftp#config['user'], g:mmsftp#config['host'], remotepath)
		call mmsftp#info_message(printf('Downloading %s from %s...', remotepath, g:mmsftp#config['host']))
		silent execute cmd
		call mmsftp#info_message('Done! Saving...')
		silent execute 'w'
	endif
endfunction

function! mmsftp#upload_file()
	if mmsftp#is_enabled() && has_key(g:mmsftp#config, 'host')
		let localpath = mmsftp#get_local_path()
		let remotepath = mmsftp#get_remote_path()
		call mmsftp#info_message('Uploading')
		let cmd = printf(g:mmsftp#command . ' %s %s@%s:%s', localpath, g:mmsftp#config['user'], g:mmsftp#config['host'], remotepath)
		" silent execute cmd
		call jobstart(cmd, {'on_exit': function('mmsftp#on_upload_cb')})
	endif
endfunction

function! mmsftp#connect_to_remote()
	if mmsftp#is_enabled() && has_key(g:mmsftp#config, 'host')
		let cmd = 'vsplit term://sshpass -p ' . g:mmsftp#config['pass'] . ' ssh -t ' . g:mmsftp#config['user'] . '@' . g:mmsftp#config['host']
		if has_key(g:mmsftp#config, 'remote')
			let cmd = cmd . ' \"cd ' . g:mmsftp#config['remote'] . ' && bash\"' 
		endif
		silent execute cmd
	endif
endfunction

function! mmsftp#copy_remote()
	if mmsftp#is_enabled() && has_key(g:mmsftp#config, 'remote')
		let @+=g:mmsftp#config['remote']
	else
		call mmsftp#info_message('No remote set in .hsftp')
	endif
endfunction

function! mmsftp#upload_on_save()
	if mmsftp#is_enabled() && has_key(g:mmsftp#config, 'upload_on_save')
		if g:mmsftp#config['upload_on_save'] == 1
			let localpath = mmsftp#get_local_path()
			let remotepath = mmsftp#get_remote_path()
			" call mmsftp#info_message('Uploading')
			let cmd = printf(g:mmsftp#command . ' %s %s@%s:%s', localpath, g:mmsftp#config['user'], g:mmsftp#config['host'], remotepath)
			" silent execute cmd
			call jobstart(cmd, {'on_exit': function('mmsftp#on_upload_cb')})
		endif
	endif
endfunction

function! mmsftp#configure()
	call mmsftp#info_message('Reloading SFTP configuration')
	let g:mmsftp#config = mmsftp#load_config()

	if has_key(g:mmsftp#config, 'upload_on_save')
		if g:mmsftp#config['upload_on_save'] == 1
			augroup mmsftp#upload_on_save
				au!
				au BufWritePost * call mmsftp#upload_on_save()
			augroup END
		else
			augroup mmsftp#upload_on_save
				au!
			augroup END
			augroup! mmsftp#upload_on_save
		endif
	endif
endfunction

augroup mmsftp
	au! BufWritePost .hsftp call mmsftp#configure()
augroup END

command! Hdiff call mmsftp#diff_remote()
command! Hdownload call mmsftp#download_file()
command! Hupload call mmsftp#upload_file()
command! DiffRemote call mmsftp#diff_remote()
command! DownloadFileFromRemote call mmsftp#download_file()
command! UploadFileToRemote call mmsftp#upload_file()
command! ConnectToRemote call mmsftp#connect_to_remote()
command! CopyRemoteToBuffer call mmsftp#copy_remote()

