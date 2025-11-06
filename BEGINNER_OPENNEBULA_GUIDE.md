# 🚀 Complete Beginner's Guide to OpenNebula Installation

## Step 1: Basic System Setup

### 1.1 Check Your System
First, let's see what we're working with:

```bash
# Check Ubuntu version
cat /etc/os-release

# Check available memory (should be 4GB+)
free -h

# Check available disk space (should be 20GB+)
df -h

# Check if you have sudo privileges
sudo whoami
```

**Expected Output:**
- Ubuntu 22.04 or similar
- Memory: ~4GB
- Disk: ~20GB available
- sudo should return "root"

### 1.2 Update Your System
Always start with a system update:

```bash
# Update package lists
sudo apt update

# Upgrade existing packages (optional but recommended)
sudo apt upgrade -y
```

**What this does:** Downloads the latest package information and optionally upgrades installed packages.

---

## Step 2: Install Essential Tools

### 2.1 Install Core Utilities
These are basic Linux tools that might be missing:

```bash
# Install essential system tools
sudo apt install -y coreutils util-linux curl wget gnupg ca-certificates lsb-release
```

**What each tool does:**
- `coreutils`: Basic commands like `tee`, `cat`, `ls`
- `util-linux`: System utilities
- `curl/wget`: Download tools
- `gnupg`: Encryption/signing tools
- `ca-certificates`: SSL certificates
- `lsb-release`: System version info

### 2.2 Install Development Tools
These are needed to compile and run OpenNebula:

```bash
# Install programming tools
sudo apt install -y ruby ruby-dev make gcc g++ sqlite3 libsqlite3-dev build-essential
```

**What each tool does:**
- `ruby`: Programming language (OpenNebula is written in Ruby)
- `ruby-dev`: Ruby development headers
- `make/gcc/g++`: Compilers for building software
- `sqlite3`: Lightweight database
- `build-essential`: Meta-package with common build tools

---

## Step 3: Add OpenNebula Repository

### 3.1 Download and Add Security Key
OpenNebula packages are signed for security:

```bash
# Download OpenNebula's security key
wget -q -O- https://downloads.opennebula.io/repo/repo2.key | sudo gpg --dearmor -o /usr/share/keyrings/opennebula-archive-keyring.gpg
```

**What this does:** Downloads OpenNebula's GPG key and converts it to the proper format for modern Ubuntu.

### 3.2 Add Package Repository
Tell Ubuntu where to find OpenNebula packages:

```bash
# Add OpenNebula repository
echo "deb [signed-by=/usr/share/keyrings/opennebula-archive-keyring.gpg] https://downloads.opennebula.io/repo/6.8/Ubuntu/22.04 stable opennebula" | sudo tee /etc/apt/sources.list.d/opennebula.list
```

**What this does:** Creates a file that tells Ubuntu to look for OpenNebula packages in their official repository.

### 3.3 Update Package Lists
Now Ubuntu knows about OpenNebula packages:

```bash
# Update package lists to include OpenNebula
sudo apt update
```

**Verify it worked:**
```bash
# Search for OpenNebula packages
apt search opennebula | head -5
```

You should see OpenNebula packages listed.

---

## Step 4: Install OpenNebula

### 4.1 Install Frontend Components
This installs the web interface and management tools:

```bash
# Install OpenNebula frontend (web interface + management)
sudo apt install -y opennebula opennebula-sunstone opennebula-gate opennebula-flow
```

**What each package does:**
- `opennebula`: Core OpenNebula daemon
- `opennebula-sunstone`: Web interface (like a website to manage VMs)
- `opennebula-gate`: VM configuration service
- `opennebula-flow`: Service orchestration

### 4.2 Install Compute Components
This allows your machine to run virtual machines:

```bash
# Install compute node components
sudo apt install -y opennebula-node opennebula-rubygems
```

### 4.3 Install Virtualization
This installs the actual VM technology:

```bash
# Install KVM virtualization
sudo apt install -y qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils
```

**What this does:**
- `qemu-kvm`: The actual hypervisor that runs VMs
- `libvirt-*`: Management tools for VMs
- `bridge-utils`: Network bridging tools

---

## Step 5: Configure Services

### 5.1 Start Virtualization Services
```bash
# Enable and start libvirt (VM management)
sudo systemctl enable libvirtd
sudo systemctl start libvirtd
```

### 5.2 Start OpenNebula Services
```bash
# Enable services to start automatically
sudo systemctl enable opennebula opennebula-sunstone opennebula-gate opennebula-flow

# Start the services now
sudo systemctl start opennebula opennebula-sunstone opennebula-gate opennebula-flow
```

### 5.3 Check Service Status
```bash
# Check if services are running
sudo systemctl status opennebula
sudo systemctl status opennebula-sunstone
```

**Expected output:** Should show "active (running)" in green.

---

## Step 6: Configure User Access

### 6.1 Add Yourself to VM Group
```bash
# Add your user to libvirt group (allows VM management)
sudo usermod -a -G libvirt $USER

# You need to log out and back in for this to take effect
# For now, we'll continue with sudo
```

### 6.2 Configure OpenNebula Admin User
OpenNebula creates a user called "oneadmin":

```bash
# Create SSH key for oneadmin user
sudo -u oneadmin ssh-keygen -t rsa -N "" -f /var/lib/one/.ssh/id_rsa

# Set proper permissions
sudo -u oneadmin chmod 700 /var/lib/one/.ssh
sudo -u oneadmin chmod 600 /var/lib/one/.ssh/id_rsa
sudo -u oneadmin chmod 644 /var/lib/one/.ssh/id_rsa.pub
```

---

## Step 7: Access OpenNebula

### 7.1 Get Your IP Address
```bash
# Find your IP address
ip addr show | grep 'inet ' | grep -v '127.0.0.1'
```

**Note the IP address** (something like 192.168.1.100)

### 7.2 Get Login Password
```bash
# Get the auto-generated password
sudo cat /var/lib/one/.one/one_auth
```

**Save this password** - you'll need it to log in.

### 7.3 Access Web Interface
1. Open your web browser
2. Go to: `http://localhost:9869` (replace YOUR_IP_ADDRESS)
3. Login with:
   - **Username:** `oneadmin`
   - **Password:** (the password from step 7.2)

---

## Step 8: Verify Everything Works

### 8.1 Check Web Interface
- You should see the OpenNebula dashboard
- Look for "Hosts" in the left menu - you should see your local machine

### 8.2 Test Command Line
```bash
# Test basic OpenNebula commands
sudo -u oneadmin onehost list
sudo -u oneadmin oneimage list
```

---

## 🛠️ Troubleshooting

### If services won't start:
```bash
# Check logs
sudo journalctl -u opennebula -f
sudo journalctl -u opennebula-sunstone -f
```

### If web interface doesn't load:
```bash
# Check if port 9869 is open
sudo netstat -tlnp | grep 9869

# Restart web interface
sudo systemctl restart opennebula-sunstone
```

### If you can't access from another computer:
```bash
# Check firewall (Ubuntu's UFW)
sudo ufw status
sudo ufw allow 9869/tcp  # if firewall is active
```

---

## 🎉 Next Steps

Once everything is working:

1. **Create your first VM** through the web interface
2. **Add more compute nodes** (other computers) to your cloud
3. **Deploy applications** like your sentiment analyzer

---

## 📞 Quick Help Commands

Save these for later:

```bash
# Restart all OpenNebula services
sudo systemctl restart opennebula opennebula-sunstone opennebula-gate opennebula-flow

# Check service status
sudo systemctl status opennebula opennebula-sunstone

# View OpenNebula logs
sudo tail -f /var/log/one/oned.log

# Get web interface password
sudo cat /var/lib/one/.one/one_auth

# List all VMs
sudo -u oneadmin onevm list

# Get your IP address
hostname -I
```

**That's it! You now have OpenNebula running on your system! 🚀**