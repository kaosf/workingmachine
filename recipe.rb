require 'itamae/secrets'

cryptography_passphrase = Itamae::Secrets(File.join(__dir__, 'secret'))['cryptography_passphrase']

username = `whoami`.strip # "myname\n".strip #=> "myname"
user username do
  shell '/bin/bash'
end

group username
directory "/home/#{username}" do
  owner username
  group username
end

directory "/home/#{username}/.ssh" do
  owner username
  group username
  mode '700'
end

execute "cp /root/.ssh/authorized_keys /home/#{username}/.ssh/authorized_keys"
execute "chown #{username}: /home/#{username}/.ssh/authorized_keys"

encrypted_remote_file "/home/#{username}/.ssh/id_rsa" do
  source './id_rsa.encrypted'
  owner username
  group username
  mode '400'
  password cryptography_passphrase
end

encrypted_remote_file "/home/#{username}/.ssh/id_rsa.pub" do
  source './id_rsa.pub.encrypted'
  owner username
  group username
  mode '444'
  password cryptography_passphrase
end

encrypted_remote_file "/home/#{username}/.ssh/config" do
  source './ssh-config.encrypted'
  owner username
  group username
  mode '600'
  password cryptography_passphrase
end

encrypted_remote_file "/home/#{username}/.ssh/known_hosts" do
  source './ssh-known_hosts.encrypted'
  owner username
  group username
  mode '600'
  password cryptography_passphrase
end

execute "echo '#{username} ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers"

include_recipe './cookbooks/openssh/default.rb'

service 'sshd' do
  action [:restart]
end

execute 'pacman --noconfirm -Syu'
package 'mosh'
package 'tmux'
package 'wget'
package 'git'

execute 'Create .tmux.conf' do
  command <<-EOH
wget https://raw.githubusercontent.com/kaosf/dotfiles/master/.tmux.conf -O /home/#{username}/.tmux.conf
chown #{username}: /home/#{username}/.tmux.conf
chmod 644 /home/#{username}/.tmux.conf
EOH
end

file "/home/#{username}/.bash_profile" do
  content <<-EOH
export PROMPT_COMMAND=__prompt_command
function __prompt_command() {
  local EXIT="$?"
  PS1='[\\u@\\h \\w'
  if [ $EXIT != 0 ]; then PS1+=" $EXIT"; fi
  PS1+="]\\n\\$ "
}
alias rm='rm -i'
alias ls='ls --color=auto'
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
EOH
  owner username
  group username
  mode '600'
end

file "/home/#{username}/setup.sh" do
  content <<-EOH
#!/bin/bash
set -x
#{Itamae::Secrets(File.join(__dir__, 'secret'))['setup_script']}
EOH
  owner username
  group username
  mode '755'
end

encrypted_remote_file "/home/#{username}/passphrase.txt" do
  source './passphrase.txt.encrypted'
  owner username
  group username
  mode '400'
  password cryptography_passphrase
end
