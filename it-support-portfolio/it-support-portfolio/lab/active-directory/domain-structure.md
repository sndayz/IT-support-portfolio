# Active Directory: Domain Structure

## Overview

- **Domain:** `lab.local` (single domain, single forest)
- **Domain controller:** `DC01` (Windows Server 2022 VM)
- **Domain-joined machines:** Windows 11 Enterprise VM, Linux Ubuntu VM
- **Purpose:** practice environment for Tier 1 help desk skills: account management, group-based access, and later Group Policy

## Design goals

An OU is created only if it serves at least one of these:

1. **Policy:** a GPO should apply to its contents and not to others
2. **Delegation:** someone should administer it without administering everything
3. **Housekeeping:** it clearly makes the directory easier to navigate (the weakest reason)

Two rules guide the design:

- **OUs manage, groups grant access.** Who can open a folder is decided by security groups, not by where an account sits.
- **User settings follow the user object's OU, computer settings follow the computer object's OU.** A user GPO linked to a computers-only OU does nothing.

## Structure type: hybrid

The top level is split by **object type**. A second level is added only where it earns its place: **department** for user accounts, **operating system** for workstations, and **function** for groups. Computers are not split by department.

```
lab.local
├─ Staff
│  ├─ Finance
│  ├─ HR
│  ├─ IT
├─ Disabled Accounts
├─ Domain Controllers
├─ Groups
│  ├─ Roles (GG)
│  └─ Access (DL)
├─ Servers
└─ Workstations
   ├─ Windows
   ├─ Linux
   └─ Staging
```

### Why each OU exists

| OU                        | Policy                                                        | Delegation                                          | Housekeeping | Notes                                                                                 |
| ------------------------- | ------------------------------------------------------------- | --------------------------------------------------- | ------------ | ------------------------------------------------------------------------------------- |
| Staff / Finance, HR, IT   | Per-department user settings (desktop config, drive mappings) | A department admin could manage one department only | Yes          | Holds user accounts only                                                              |
| Disabled Accounts | A restrictive policy could apply to offboarded accounts       |                                                     | Yes          | Keeps live OUs clean                       |
| Domain Controllers        | Default Domain Controllers Policy                             |                                                     |              | Built-in, left untouched                                                              |
| Groups / Roles (GG)       |                                                               | Group management can be delegated separately        | Yes          | Global groups: roles such as HR staff                                                 |
| Groups / Access (DL)      |                                                               | Group management can be delegated separately        | Yes          | Domain local groups placed on resource ACLs                                           |
| Servers                   | Server baseline (planned)                                     | Server admins                                       |              | Empty for now; split by role only when policies differ                                |
| Workstations              | Workstation baseline (planned)                                |                                                     |              | Computer settings for all workstations                                                |
| Workstations / Windows    | Windows-specific settings                                     |                                                     | Yes          |                                                                                       |
| Workstations / Linux      | Not by default                                                |                                                     | Yes          | Windows GPOs do not apply to Linux machines, so this is organisation, not policy      |
| Workstations / Staging    |                                                               |                                                     | Yes          | New machines land here (via redircmp) until configured, then move to Windows or Linux |

### What this design makes easy

- **User policies per department.** A drive mapping or desktop setting for Finance is one link at the Finance OU.
- **Computer policies per device type.** A baseline for all workstations is one link at Workstations, and OS-specific rules go at Windows.
- **Offboarding.** Moving an account to Disabled Accounts removes its department policies in one step.
- **AGDLP.** Role groups and access groups are kept apart, matching how they are used.

### What it makes harder

- **Computer policies per department.** "Block USB on Finance PCs" cannot be done by OU, because computers are not grouped by department. Options: security group filtering on the GPO, or adding a department level under Workstations later.
- **Inheritance into child OUs.** Anything linked to Workstations reaches Staging.

### Open questions and decisions

- **Placement of Staging.** Under Workstations it inherits the workstation baseline. TODO: keep it there (new machines get the baseline immediately) or move it out (new machines get no policy until configured), and why.
  
## Groups and permissions

Access follows the **AGDLP** model: Accounts go into Global groups, Global groups go into Domain Local groups, and Domain Local groups receive the Permissions.

- **Global group (GG):** collects users by role, for example `GG_HR_Users`
- **Domain local group (DL):** holds the permission and is the group placed on the ACL, for example `DL_HR_Share_RW`
- **Example chain:** user → `GG_..._HR_Users` → `DL_HR_Share_RW` → Modify on the HR share



TODO: list the groups you actually created, and which share or resource each DL protects.

## Issues hit and what I learned

- **"Name already in use" when creating an OU called `Users` at the domain root.** AD requires a name to be unique among objects with the same parent, even across object types (a container and an OU). The built-in `Users` container holds the built-in accounts and groups the domain depends on, so the fix was choosing a different name, not replacing the container.
- **Placement of staging and Disabled Accounts**
- TODO: add other problems you ran into while restructuring, and how you diagnosed them.

## Not yet implemented

- Group Policy (to be rebuilt from scratch, user and computer settings separated)
- Delegation of Control for the help desk group
- Ideas under consideration:  staging OU for new computers with default OU redirection for new users and computers

## Change log

| Date | Change |
|---|---|
| 2026-10-22 | Documented the structure while the restructure is in progress |
