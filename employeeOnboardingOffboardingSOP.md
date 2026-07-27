# Employee Onboarding & Offboarding Standard Operating Procedure

## Document Control

| Field | Value |
|-------|-------|
| **SOP ID** | TAB-SOP-IT-001 |
| **Title** | Employee Onboarding & Offboarding (IT Account Lifecycle) |
| **Version** | 1.0 |
| **Status** | Approved |
| **Effective Date** | 2026-07-27 |
| **Next Review Date** | 2027-07-27 |
| **Review Cycle** | Annual, or upon material change to systems/regulation |
| **Document Owner** | IT Operations Manager |
| **Approved By** | Chief Information Officer |
| **Data Classification** | Internal Use Only |

> **Note:** This is a controlled document. The authoritative copy is the version stored in the `techaboo-documents` repository. Printed or locally saved copies are uncontrolled and may be out of date.

---

## 1. Purpose

This Standard Operating Procedure (SOP) defines the standardized, repeatable, and auditable process for provisioning IT access to new employees (**onboarding**) and revoking that access when an employee leaves or changes roles (**offboarding**). It exists to ensure that:

- Every worker receives the correct access on or before their start date (the *principle of least privilege*).
- Access is fully and promptly revoked upon separation, closing security and compliance gaps.
- Actions are consistent, documented, and traceable for audit purposes.

## 2. Scope

**In scope:** All Techaboo Inc. employees, contractors, interns, and third parties who require access to corporate IT systems, including Active Directory (AD), Microsoft 365 / Azure AD, corporate endpoints (Windows and Linux), collaboration tools (Microsoft Teams), and mobile devices.

**Out of scope:** Physical security/badging (covered by the Facilities SOP), payroll and benefits enrollment (Human Resources), and application-specific business processes owned by individual departments.

## 3. Definitions and Acronyms

| Term | Definition |
|------|------------|
| **AD** | Active Directory — on-premises identity and directory service. |
| **Azure AD / Entra ID** | Microsoft's cloud identity service backing Microsoft 365. |
| **FSMO** | Flexible Single Master Operations — AD domain controller roles. |
| **JML** | Joiner–Mover–Leaver — the identity lifecycle model this SOP implements. |
| **Least Privilege** | Granting only the minimum access required to perform a role. |
| **MFA / 2FA** | Multi-Factor / Two-Factor Authentication. |
| **RSAT** | Remote Server Administration Tools. |
| **SLA** | Service Level Agreement — the time target for completing a task. |
| **Ticket** | A tracked request in the IT service management (ITSM) system. |

## 4. Roles and Responsibilities (RACI)

| Activity | HR | Hiring Manager | IT Service Desk | IT Operations | Security |
|----------|----|----------------|-----------------|---------------|----------|
| Submit onboarding/offboarding request | **R** | **A** | I | I | I |
| Approve access level | C | **A** | I | **R** | C |
| Provision accounts & devices | I | I | **R** | **A** | I |
| Revoke access on separation | I | **A** | **R** | **A** | C |
| Verify completion / audit | I | I | C | **R** | **A** |

**Legend:** R = Responsible, A = Accountable, C = Consulted, I = Informed.

## 5. Prerequisites

Before executing this procedure, ensure the following:

- A ticket has been raised in the ITSM system by HR or the hiring manager, containing: full legal name, preferred name, job title, department, manager, start/end date, and required systems.
- The operator holds delegated administrative rights in AD and Azure AD sufficient for the task, and performs the work from a managed administrative workstation with [RSAT installed](installRSAT.md).
- MFA is available and enforced for all administrative accounts.
- All credentials are generated and stored only in the approved corporate password manager — **never** in scripts, tickets, email, or chat.

## 6. Procedure — Onboarding (Joiner)

**Target SLA: complete no later than 1 business day before the employee's start date.**

### 6.1 Pre-Arrival (T-minus 3 business days)

1. Confirm the onboarding ticket contains all required fields (Section 5). Reject and return incomplete tickets to the requester.
2. Determine the access profile by comparing against an existing peer ("model user") in the same role, verified with the hiring manager.
3. Reserve a corporate device and confirm licensing availability in Microsoft 365.

### 6.2 Identity & Account Creation

1. Create the Active Directory account. Where a role-equivalent model user exists, use the approved provisioning script to clone attributes and group memberships: see [Active Directory Account Creation](activeDirectoryAccountCreation.md).
   - Set the account name to the corporate standard: `firstname.lastname`.
   - Generate a unique strong initial password in the password manager and set "user must change password at next logon."
   - Apply least privilege — remove any inherited group that is not required for the new role.
2. Confirm the correct Microsoft 365 / Azure AD license and security-group assignments. Validate group membership using the reporting method in [Azure Job Title Script](azureJobTitleScript.md).
3. Enroll the account in MFA before first sign-in.

### 6.3 Endpoint & Application Provisioning

1. Provision the corporate workstation and enroll it in device management.
2. Install standard software using the approved package tooling:
   - Windows updates and standard apps via [WinGet](winGet.md).
   - [Microsoft Teams](installTeams.md) for collaboration.
   - Administrative tooling, where the role requires it, via [Install RSAT](installRSAT.md).
3. For mobile devices, apply the corporate security baseline, including [iPhone / iCloud encryption](iphoneEncryption.md).

### 6.4 Handover & Verification

1. Confirm the employee can sign in, complete MFA registration, and reach required resources.
2. Deliver credentials to the employee through a secure channel (in person or via the password manager's secure-share feature). Do not send passwords by plain email.
3. Update the ticket with all actions taken and close it. Notify the hiring manager that provisioning is complete.

## 7. Procedure — Offboarding (Leaver)

**Target SLA: disable access within 1 hour of the effective separation time for a standard departure, and immediately for an involuntary or high-risk departure.**

> **Priority:** For involuntary terminations, revocation is performed **before** the employee is notified, coordinated with HR and Security. Disable first, delete later.

1. **Disable, do not delete.** Immediately disable the AD account and revoke active Microsoft 365 / Azure AD sessions and tokens. Reset the password to a random value so the account cannot be reused.
2. **Revoke access:** remove the user from all security and distribution groups; revoke application and VPN access; disable MFA methods tied to the departing person.
3. **Secure data:** convert the mailbox to shared or place it on litigation/retention hold per the data retention policy; delegate the manager access to files as required for business continuity.
4. **Recover assets:** collect corporate devices; remotely wipe or retire enrolled mobile devices; return hardware to inventory.
5. **Forwarding & handover:** set up email forwarding or an auto-reply only where business-justified and approved, for the minimum necessary period.
6. **Deletion:** after the retention period defined in the data retention policy (default 30 days unless legal hold applies), permanently delete or archive the account.
7. **Verify & record:** confirm all steps, update the ticket with evidence (timestamps, screenshots where appropriate), and close it. Security reviews a sample of offboarding tickets monthly.

## 8. Verification and Quality Assurance

- Every onboarding and offboarding action must be recorded in the ITSM ticket, which serves as the audit trail.
- IT Operations performs a monthly reconciliation of active AD/Azure AD accounts against the HR active-employee roster; orphaned or stale accounts are investigated and remediated.
- Directory health that underpins account operations (including [AD FSMO role holders](adfsmoholdercheck.md)) is checked as part of routine operations.

## 9. Records and Retention

| Record | Location | Retention |
|--------|----------|-----------|
| Onboarding/offboarding tickets | ITSM system | 3 years |
| Access-approval evidence | ITSM ticket / IAM logs | 3 years |
| Monthly account reconciliation reports | IT Operations share | 1 year |
| Departed-user mailbox/data | Per data retention policy | 30 days (unless legal hold) |

## 10. Compliance and References

This SOP supports Techaboo Inc.'s alignment with recognized security and governance frameworks, including:

- **ISO/IEC 27001:2022** — Annex A controls for access control and identity lifecycle (A.5.15–A.5.18).
- **NIST SP 800-53** — AC (Access Control) and PS (Personnel Security) control families.
- **CIS Controls v8** — Control 5 (Account Management) and Control 6 (Access Control Management).
- Principle of **least privilege** and **segregation of duties**.

**Related internal documents:** [Active Directory Account Creation](activeDirectoryAccountCreation.md), [Azure Job Title Script](azureJobTitleScript.md), [Install RSAT](installRSAT.md), [WinGet Update](winGet.md), [Install Microsoft Teams](installTeams.md), [AD FSMO Role Check](adfsmoholdercheck.md), [iPhone Encryption Instructions](iphoneEncryption.md).

## 11. Exceptions

Any deviation from this SOP requires documented approval from the Document Owner (IT Operations Manager) and, where security controls are affected, the Security team. Exceptions are recorded in the ITSM ticket with a justification and an expiry date.

## 12. Revision History

| Version | Date | Author | Description |
|---------|------|--------|-------------|
| 1.0 | 2026-07-27 | IT Operations | Initial approved release. |
