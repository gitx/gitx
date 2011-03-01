tell application "iTerm"
	activate
	try
		set myterm to the first terminal
	on error
		set myterm to (make new terminal)
	end try
	tell myterm
		launch session "gitx"
		tell the last session
			set name to "Opened by GitX"
			exec command "/bin/bash"
			write text "cd %%workDir%%; clear; echo '# Opened by GitX:'; git status"
		end tell
	end tell
end tell
