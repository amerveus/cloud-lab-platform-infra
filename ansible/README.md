# Ansible: ops host configuration over AWS SSM

Configures EC2 hosts tagged `Role=ops-host`. There is no SSH: Ansible connects through
AWS Systems Manager, and sshd is disabled on the hosts.

## Run

    "$(brew --prefix ansible)/libexec/bin/python" -m pip install boto3 botocore   # once
    ansible-galaxy collection install -r requirements.yml                         # once
    ansible-inventory --graph            # hosts discovered from EC2 tags
    ansible-playbook site.yml            # converge
    ansible-playbook site.yml            # second run should report changed=0

## Design

- **Inventory:** `amazon.aws.aws_ec2`, filtered by `Project` and `Role` tags; grouped by
  `ec2_tags.Role` and `ec2_tags.Environment`. No hard-coded hosts.
- **Connection:** `amazon.aws.aws_ssm`, file transfer via the per-environment S3 bucket
  (objects expire after 1 day). Requires the AWS session-manager-plugin locally.
- **baseline:** security updates, chrony, auditd, sshd stopped and disabled, sysctl
  network hardening, login banner.
- **node_exporter:** pinned release, download verified against the published SHA-256
  checksums, no-login system user, hardened systemd unit, listening on :9100 (reachable
  only from the EKS node security group).

## Known warning

The `amazon.aws` inventory plugin emits a deprecation warning for its legacy `tags` host
variable. This code uses `ec2_tags` exclusively, so the planned removal does not affect it.
Deprecation warnings are intentionally left enabled so future ones still surface.
