# Private preview status

The source was saved as Sites version 1. Both private deployment attempts failed
with HTTP 409 Conflict during hosting sign-in callback registration. There is
no live hosted URL. The frontend code and local production build are complete;
this failure is in the hosting service, not the application build.

- Site: `appgprj_6aa02f7de2d48191b71235158992a715`
- Saved version: `appgprj_6aa02f7de2d48191b71235158992a715~appgver_7e62f0479fb8819193b5466bd4bad5cc`
- Initial deployment: `appgdep_6aa03078e04881919711d587b156c4b2`
- Retry deployment: `appgdep_6aa03099d17481919d008a7c628c5695`

The existing site and saved version can be reused after the hosting service
resolves its callback-registration conflict. Do not create another site.

Run `npm run dev` and open `http://localhost:5179/` for the local prototype.
