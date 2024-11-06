#!/bin/bash
# Function to check command success
check_success() {
  if [ $? -ne 0 ]; then
    echo "Error: $1 failed. Exiting..."
    exit 1
  fi
}

# Function to check if a package is installed
is_installed() {
  dpkg -l | grep -q $1
}

echo "Updating system..."
sudo apt-get update && sudo apt-get upgrade -y
check_success "System update"

# Install essential packages
echo "Installing essential packages..."
ESSENTIAL_PACKAGES=("python3" "python3-pip" "python3-venv" "git" "openssl" "libssl-dev" "curl")
for package in "${ESSENTIAL_PACKAGES[@]}"; do
  if ! is_installed $package; then
    sudo apt-get install -y $package
    check_success "$package installation"
  else
    echo "$package is already installed. Skipping."
  fi
done

# Clone CALDERA repository with submodules
if [ ! -d "caldera" ]; then
  echo "Cloning CALDERA repository..."
  git clone https://github.com/mitre/caldera.git --recursive
  check_success "Cloning CALDERA repository"
else
  echo "CALDERA repository already exists. Skipping clone."
fi

cd caldera

# Install Python dependencies
echo "Installing Python dependencies..."
pip3 install -r requirements.txt
check_success "Python dependencies installation"

# Upgrade pyOpenSSL
if ! python3 -c "import OpenSSL" &> /dev/null; then
  echo "Upgrading pyOpenSSL..."
  pip3 install --upgrade pyOpenSSL
  check_success "pyOpenSSL upgrade"
else
  echo "pyOpenSSL is already upgraded. Skipping."
fi

# Install Go (Golang)
if ! command -v go &> /dev/null; then
  echo "Installing Go (Golang)..."
  GO_VERSION="1.21.1"
  wget https://go.dev/dl/go$GO_VERSION.linux-amd64.tar.gz
  check_success "Go download"
  sudo rm -rf /usr/local/go && sudo tar -C /usr/local -xzf go$GO_VERSION.linux-amd64.tar.gz
  check_success "Go installation"
  rm go$GO_VERSION.linux-amd64.tar.gz
  export PATH=$PATH:/usr/local/go/bin
  echo "export PATH=\$PATH:/usr/local/go/bin" >> ~/.profile
  source ~/.profile
  check_success "Go path setup"
else
  echo "Go is already installed. Skipping."
fi

# Install Node.js and npm
if ! command -v node &> /dev/null; then
  echo "Installing Node.js and npm..."
  curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
  check_success "Node.js setup script"
  sudo apt-get install -y nodejs
  check_success "Node.js and npm installation"
else
  echo "Node.js and npm are already installed. Skipping."
fi

# Install missing Docker module for the builder plugin
if ! pip show docker &> /dev/null; then
  echo "Installing Docker Python module..."
  pip install docker
  check_success "Docker module installation"
else
  echo "Docker module is already installed. Skipping."
fi

# Install UPX for optional functionality
if ! command -v upx &> /dev/null; then
  echo "Installing UPX..."
  sudo apt-get install -y upx
  check_success "UPX installation"
else
  echo "UPX is already installed. Skipping."
fi

# Fetch the VPS IP address using curl ip.me
VPS_IP=$(curl -s ip.me)
if [ -z "$VPS_IP" ]; then
  echo "Error: Unable to retrieve VPS IP address."
  exit 1
fi
echo "VPS IP retrieved: $VPS_IP"

# Update IP in caldera/conf/default.yml
if [ -f "conf/default.yml" ]; then
  echo "Updating IP in caldera/conf/default.yml..."
  sed -i "s|http://[0-9\.]*:8888|http://$VPS_IP:8888|g" conf/default.yml
  sed -i "s|http://localhost:8888|http://$VPS_IP:8888|g" conf/default.yml
else
  echo "caldera/conf/default.yml not found. Skipping IP update."
fi

# Update IP in caldera/plugins/magma/.env
if [ -f "plugins/magma/.env" ]; then
  echo "Updating IP in caldera/plugins/magma/.env..."
  sed -i "s|VITE_CALDERA_URL=http://[0-9\.]*:8888|VITE_CALDERA_URL=http://$VPS_IP:8888|g" plugins/magma/.env
  sed -i "s|VITE_CALDERA_URL=http://localhost:8888|VITE_CALDERA_URL=http://$VPS_IP:8888|g" plugins/magma/.env
else
  echo "caldera/plugins/magma/.env not found. Skipping IP update."
fi

echo "IP address updated successfully to $VPS_IP in both files if they existed."

# Configure and start CALDERA server
echo "Starting CALDERA server..."
python3 server.py --insecure --build
check_success "CALDERA server start"

echo "CALDERA installation and startup complete."