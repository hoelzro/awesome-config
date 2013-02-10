local audio = {}

function audio.next()
  os.execute 'tmux send-keys -t pmus:1 l'
end

function audio.previous()
  os.execute 'tmux send-keys -t pmus:1 h'
end

function audio.toggle()
  os.execute 'mpc toggle'
end

function audio.stop()
  os.execute 'mpc stop'
end

return audio
