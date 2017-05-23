#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# FILE: bootstrap.sh
# DESCRIPTION: Bootstrap script to install your ServerPilot boxes
# AUTHOR: Toan Nguyen (destro [at] nnt [dot] com)
# VERSION: 1.0.0
# ------------------------------------------------------------------------------
set -e

while getopts "i:k:s:p:b:z:" opt; do
    case "$opt" in
        i)
          server_id="$OPTARG" ;;
        k)
          api_key="$OPTARG" ;;
        s)
          sudo_nopasswd="$OPTARG" ;;
        p)
          default_php="$OPTARG" ;;
        b)
          install_omb="$OPTARG" ;;
        z)
          install_omz="$OPTARG" ;;
    esac
done

# Default user vars
user="ubuntu"
homedir=$(getent passwd $user | cut -d ':' -f6)

# SP user vars
sp_user="serverpilot"
sp_homedir=$(getent passwd $sp_user | cut -d ':' -f6)
sp_sudoers="/etc/sudoers.d/$sp_user"
sp_agentlog="/var/log/serverpilot/agent.log"
sp_installer="serverpilot-installer"

sp_tweak()
{
  sudo cp /root/.my.cnf "$sp_homedir"/.my.cnf &>/dev/null
  sudo chown $sp_user:$sp_user "$sp_homedir"/.my.cnf &>/dev/null
  sudo cp "$homedir"/.ssh/authorized_keys "$sp_homedir"/.ssh/authorized_keys &>/dev/null
  sudo chown $sp_user:$sp_user "$sp_homedir"/.ssh/authorized_keys &>/dev/null
  if [[ "$sudo_nopasswd" == true ]]; then
    echo "serverpilot ALL=(ALL) NOPASSWD:ALL" | sudo tee "$sp_sudoers" && sudo chmod 440 "$sp_sudoers" &>/dev/null
    echo "env bash'" | sudo tee "$sp_homedir"/.bash_profile &>/dev/null
    sudo chown $sp_user:$sp_user "$sp_homedir"/.bash_profile
  fi
  # Set default PHP version
  echo "Setting default PHP version..."
  echo "sp-php-cli sp-php-cli/default_php_version select $default_php" | sudo debconf-set-selections
  sudo dpkg-reconfigure -f noninteractive sp-php-cli
  # WIP - not working, don't know why.
  if [[ "$install_omb" == true && "$install_omz" != true ]]; then
    sudo -u $sp_user bash -c "$(curl -fsSL https://raw.github.com/ohmybash/oh-my-bash/master/tools/install.sh)"
  fi
  if [[ "$install_omz" == true && "$install_omb" != true ]]; then
    sudo apt-get -qq -y install zsh
    sudo -u $sp_user bash -c "$(wget https://raw.github.com/nntoan/oh-my-zsh-custom/master/install.sh -O -)"
  fi
}

if [[ ! -f "$sp_installer" && ! -f "$homedir"/.sp_done ]]; then
  sudo apt-get update && sudo apt-get -y install ca-certificates wget
  sudo wget -nv -O "$sp_installer" https://download.serverpilot.io/serverpilot-installer
  sudo bash "$sp_installer" --server-id="$server_id" --server-apikey="$api_key"
fi

if [[ -f "$sp_agentlog" && ! -f "$homedir"/.sp_assume_ins && ! -f "$homedir"/.sp_done ]]; then
  echo
  echo "********************************************************************************"
  echo "Resume installing ServerPilot packages..."
  echo "Please be patient..."
  echo
  sudo tail -f "$sp_agentlog" | awk '/ACTION INFO: Performing action: enable_ssh_password_auth/{ system("sudo pkill tail"); exit; }'
  echo "$(date +%s)" > "$homedir"/.sp_assume_ins
  sudo chown $user:$user "$homedir"/.sp_assume_ins
fi

if [[ -f "$homedir"/.sp_assume_ins && ! -f "$homedir"/.sp_done ]]; then
  sp_homedir=$(getent passwd $sp_user | cut -d ':' -f6)
  echo "Start tweaking some configs for your ServerPilot bundle..."
  sp_tweak
  echo "$(date +%s)" > "$homedir"/.sp_done
  sudo chown $user:$user "$homedir"/.sp_done
  echo
  echo "********************************************************************************"
  echo
  echo "Your balance-vagrant is ready! Log in with: "
  echo "| - ssh ubuntu@<your_private_ip_addr> -oStrictHostKeyChecking=no -A"
  echo "Your machine credentials: "
  echo "| - username: ubuntu"
  echo "| - password: ubuntu"
fi
