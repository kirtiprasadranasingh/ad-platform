# ADaaS prototype

Open **index.html** in a browser (double-click; no server needed). Everything is mock data held in the browser; nothing leaves the page.

| File | What it is |
|---|---|
| **index.html** | The app: public site (Home, See, Learn, Understand, Partner, Talk to AD), registration, sign-in with role-based menus, Salesy onboarding with a setup stepper, provisioning, then the account shell: left menu with Overview, AD (Data, Produce, Explore, Generate, Work orders) and Configure (Setup, Domains, Sandboxes, People, Approvals, Usage, Audit log; admins only), top bar with the account and approvals count, and a context-aware assistant panel (ADy on AD pages, Configgy on Configure pages). Staff pick an account from the top bar. State persists in the browser; reset is on the sign-in page under “Accounts for this review”. |
| **flows.html** | The flows page for Thursday: the "top" map (where Salesy, Configgy and ADy live, where sign-in lands), vocabulary, roles, every flow with steps, mode transitions, Dec 1 cut, decisions. Each flow has a button that opens index.html in that flow. Printable. |
| adconfig.html, adaas-portal.html | Earlier iterations (Oct 27–28). Superseded by index.html. |

Review sign-ins: `bill@alidainc.com / ad` (admin), `dhananjay@alidainc.com / ad` (user), `staff@alidainc.com / ad` (Alida staff). Users invited inside the prototype get the password `welcome`.

Agents are rule-based stand-ins; provisioning and jobs are simulated with timers.
