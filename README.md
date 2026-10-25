# Terraform DevSecOps Security Lab

A hands-on comparison of an intentionally unsafe Azure NSG rule and a restricted example, with PowerShell automation for tfsec and Checkov.

> `samples/insecure` is deliberately vulnerable training material. Do not apply it, connect it to a real network, or copy its public SSH rule into a workload. The examples include no credentials and are not deployed by the scan script.

```mermaid
flowchart LR
    Code[Terraform sample] --> Scan[tfsec + Checkov]
    Scan -->|No findings| Secure[Review secure sample]
    Scan -->|Finding| Fail[Fail check and inspect result]
    Fail --> Fix[Restrict exposure and rescan]
    Fix --> Scan
```

## Samples

| Sample | Demonstration | Expected outcome |
| --- | --- | --- |
| `samples/insecure` | Inbound SSH (`22/TCP`) from any source (`*`) | At least one scanner should report a finding |
| `samples/secure` | SSH restricted to a reserved documentation `/32` range | Scanners should pass; replace the reserved range before any real use |

The secure example is still an educational snippet, not a production network design. Prefer eliminating direct SSH exposure and using a controlled management path such as Azure Bastion or a private management network.

## Install pinned tools

The PowerShell installer pins Checkov and downloads the official tfsec Windows release, verifying its published SHA-256 checksum before extraction. tfsec continues to be available, though its maintainers direct new engineering attention to Trivy. Review upstream status and compatibility before changing these versions:

```powershell
.\scripts\Install-Tools.ps1
```

The installer uses Python 3.12 or newer, `tar.exe`, and network access to PyPI and the official tfsec GitHub release. It places tools in ignored `.venv/` and `.tools/` directories.

## Run scans

From the repository root:

```powershell
.\scripts\Invoke-Scans.ps1 -Sample secure
.\scripts\Invoke-Scans.ps1 -Sample insecure
```

The secure mode fails if either scanner exits nonzero. The insecure mode fails if both scanners return success; otherwise inspect scanner output and verify that the public SSH rule was actually flagged. A tool/runtime error is not evidence of a security finding. The script never suppresses findings.

## Finding and remediation

- **Unrestricted administrative ingress:** Any-source SSH can expose management access to the internet and expands brute-force and exploit risk. Restrict source ranges at minimum, avoid public SSH where possible, and use private access paths with identity controls.
- **Secure sample:** The rule uses a single reserved documentation CIDR as a nonfunctional placeholder. Replace it with a verified trusted range only if direct SSH is explicitly required; use a jump host/Bastion pattern where appropriate.
- **Additional review:** Verify effective NSG rules, subnet association, routing, identity controls, patching, logging, and the complete network path. A static scan cannot prove a deployment is secure.

## CI integration and failure behavior

The separate Azure DevOps Terraform pipeline portfolio project demonstrates fail-on-findings tfsec and Checkov steps on a Windows self-hosted agent. Run scans against a secure baseline as a required pull-request check. Keep the insecure sample isolated from deployment roots; use it only in an intentional detection exercise and review its output.

Scanner exit codes are treated as failures in the secure path. Do not add `--soft-fail`, broad suppressions, or blanket exclusions to force CI green. For a genuine false positive, first verify the resource and scanner rule, document the rationale and owner, define a narrow/time-bound exception in the project's approved process, and retain the finding in review records. This lab contains no suppression or false-positive exception.

## Validation

Terraform formatting and backend-free validation can be run without Azure credentials:

```powershell
terraform fmt -check -recursive
Set-Location samples/secure
terraform init -backend=false
terraform validate
```

No command in this lab provisions Azure resources. `terraform validate` validates syntax/provider schema; the intentionally insecure and secure samples are not deployment instructions.
