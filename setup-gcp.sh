#!/bin/bash
# DefectDojo GCP Setup Script
# Run this on your local machine or Google Cloud Shell

set -e

echo "╔══════════════════════════════════════════════════════╗"
echo "║     DefectDojo GCP Instance Setup Script            ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

# Configuration
INSTANCE_NAME="defectdojo-server"
ZONE="us-central1-a"
MACHINE_TYPE="e2-custom-4-8192"
BOOT_DISK_SIZE="50GB"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Step 1: Creating GCP Instance...${NC}"
gcloud compute instances create $INSTANCE_NAME \
  --zone=$ZONE \
  --machine-type=$MACHINE_TYPE \
  --image-family=ubuntu-2204-lts \
  --image-project=ubuntu-os-cloud \
  --boot-disk-size=$BOOT_DISK_SIZE \
  --boot-disk-type=pd-balanced

echo -e "${GREEN}✓ Instance created${NC}"
echo ""

echo -e "${YELLOW}Step 2: Creating Firewall Rules...${NC}"

# Allow DefectDojo port
gcloud compute firewall-rules create allow-defectdojo \
  --direction=INGRESS \
  --action=ALLOW \
  --rules=tcp:8080 \
  --source-ranges=0.0.0.0/0 \
  2>/dev/null || echo "Firewall rule 'allow-defectdojo' already exists"

# Allow SSH
gcloud compute firewall-rules create allow-ssh-defectdojo \
  --direction=INGRESS \
  --action=ALLOW \
  --rules=tcp:22 \
  --source-ranges=0.0.0.0/0 \
  2>/dev/null || echo "Firewall rule 'allow-ssh-defectdojo' already exists"

echo -e "${GREEN}✓ Firewall rules configured${NC}"
echo ""

echo -e "${YELLOW}Step 3: Getting Instance IP...${NC}"
INSTANCE_IP=$(gcloud compute instances describe $INSTANCE_NAME \
  --zone=$ZONE \
  --format='get(networkInterfaces[0].accessConfigs[0].natIP)')

echo -e "${GREEN}✓ Instance IP: $INSTANCE_IP${NC}"
echo ""

echo -e "${YELLOW}Step 4: Generating SSH Key...${NC}"
SSH_KEY_PATH="$HOME/.ssh/defectdojo-key"

if [ -f "$SSH_KEY_PATH" ]; then
  echo "SSH key already exists at $SSH_KEY_PATH"
  read -p "Overwrite? (y/n) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Using existing key"
  else
    ssh-keygen -t rsa -b 4096 -f $SSH_KEY_PATH -N "" -C "defectdojo"
  fi
else
  ssh-keygen -t rsa -b 4096 -f $SSH_KEY_PATH -N "" -C "defectdojo"
fi

echo -e "${GREEN}✓ SSH key ready${NC}"
echo ""

echo -e "${YELLOW}Step 5: Adding SSH Key to Instance...${NC}"
gcloud compute instances add-metadata $INSTANCE_NAME \
  --zone=$ZONE \
  --metadata-from-file ssh-keys=$SSH_KEY_PATH.pub

echo -e "${GREEN}✓ SSH key added${NC}"
echo ""

echo -e "${YELLOW}Step 6: Testing SSH Connection...${NC}"
echo "Waiting for instance to be ready..."
sleep 10

if ssh -i $SSH_KEY_PATH -o StrictHostKeyChecking=no -o ConnectTimeout=10 ubuntu@$INSTANCE_IP "echo 'SSH working'" 2>/dev/null; then
  echo -e "${GREEN}✓ SSH connection successful${NC}"
else
  echo -e "${YELLOW}⚠ SSH connection not ready yet. This is normal.${NC}"
  echo "Try again in a minute: ssh -i $SSH_KEY_PATH ubuntu@$INSTANCE_IP"
fi
echo ""

echo -e "${YELLOW}Step 7: Generating GitHub Secrets...${NC}"
echo ""

DB_PASSWORD=$(openssl rand -base64 32)
ADMIN_PASSWORD=$(openssl rand -base64 24)
SECRET_KEY=$(openssl rand -base64 64 | tr -d '\n')

echo "Copy these values to GitHub Secrets:"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "INSTANCE_IP:"
echo "$INSTANCE_IP"
echo ""
echo "SSH_PRIVATE_KEY:"
cat $SSH_KEY_PATH
echo ""
echo "DB_PASSWORD:"
echo "$DB_PASSWORD"
echo ""
echo "ADMIN_PASSWORD:"
echo "$ADMIN_PASSWORD"
echo ""
echo "SECRET_KEY:"
echo "$SECRET_KEY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Save to file
cat > defectdojo-secrets.txt << EOF
# DefectDojo GitHub Secrets
# Add these to: GitHub Repository → Settings → Secrets and variables → Actions

INSTANCE_IP=$INSTANCE_IP

SSH_PRIVATE_KEY=
$(cat $SSH_KEY_PATH)

DB_PASSWORD=$DB_PASSWORD

ADMIN_PASSWORD=$ADMIN_PASSWORD

SECRET_KEY=$SECRET_KEY
EOF

echo -e "${GREEN}✓ Secrets saved to: defectdojo-secrets.txt${NC}"
echo ""

echo "╔══════════════════════════════════════════════════════╗"
echo "║              Setup Complete! 🎉                      ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""
echo "Next steps:"
echo "1. Copy the secrets above to GitHub"
echo "   Repository → Settings → Secrets and variables → Actions"
echo ""
echo "2. Add workflow files to your repository:"
echo "   - .github/workflows/deploy.yml"
echo "   - playbook.yml"
echo ""
echo "3. Run the GitHub Actions workflow"
echo ""
echo "4. Access DefectDojo at:"
echo "   http://$INSTANCE_IP:8080"
echo "   Username: admin"
echo "   Password: $ADMIN_PASSWORD"
echo ""
echo "Secrets saved to: defectdojo-secrets.txt"
echo ""