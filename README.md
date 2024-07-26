# kubernetes-tools
Tools, Utilities and Automation for Kubernetes Cluster Provisioning

### Prerequisites
* MicroK8s v1.30.1 or higher
* OpenSSL 3.0.2


### Purpose

1. This script will add a new ip address to the CSR Template file for Microk8s.
2. Restarts the microk8s services.
3. Generates a new key, certificate and save it to the certificate directory in microk8s.

### Help Menu

``` sh
Expand and Generate Certificate tool
Extract Configuration   [ action:{COMMAND}, --action={COMMAND} ]

COMMANDS:
Flush Older Resources   [ cleanup, flush, remove ]
Update Certificate      [ update ]

USAGES:
./generate_certificate.sh --action=update
```

### Understanding the utilites configuration template
1. The file named *util.conf.template* should have a few modification in order to update your certificate.

2. Here is how the unedited version of the configuration file looks:
<pre>
# Change these variables.
new_ip_address=123.123.123.123
update_active=false
file_owner='root:microk8s'

# IMPORTANT: Do not edit the following variables.
template="csr.conf.template"
</pre>

3. The `new_ip_address` this is used to define your new ip address that you want to add to your CA certificate. Please note that this can only be set once. If the IP Address is already in the csr.conf.template then the *generate_certificate.sh* script will just copy the *csr.conf* file and generate the new key and certificate. 

4. A variable named `update_activate` will determine if the new Key and Certificate are uploaded to the **certs** directory.

5. The `file_owner` variable defines the permission of the backup directory and the new Key and Certificate.




