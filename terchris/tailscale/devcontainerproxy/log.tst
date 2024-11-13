# Create the VM
multipass launch --name devcontainerproxy --cpus 1 --memory 1G --disk 5G --network en0 noble


# Enter the VM
multipass shell DevContainerProxy

# Inside the VM, install Tailscale
curl -fsSL https://tailscale.com/install.sh | sudo sh

# Enable IP forwarding
sudo echo 'net.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.d/99-tailscale.conf
sudo echo 'net.ipv6.conf.all.forwarding = 1' | sudo tee -a /etc/sysctl.d/99-tailscale.conf
sudo sysctl -p /etc/sysctl.d/99-tailscale.conf

# Start and enable tailscaled service
sudo systemctl start tailscaled
sudo systemctl enable tailscaled

# Connect to Tailscale and advertise as exit node
sudo tailscale up --advertise-exit-node

# Verify status
tailscale status



You'll then need to update your ACLs in the Tailscale admin console to allow this node to be an exit node by adding:
```yaml
{
	"tagOwners": {
// existing tags
		"tag:exitnode":   ["terje@businessmodel.io"],
	},
	"nodeAttrs": [
		{
			"target": ["tag:exitnode"],
			"attr": [
				"exit-node",
			],
		},
	],
}
````


sudo tailscale up --advertise-tags=tag:exitnode --advertise-exit-node


