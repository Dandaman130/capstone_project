# ✅ Railway Deployment Checklist

Print this or keep it open while configuring Railway!

---

## Step 1: Open Railway Settings
- [ ] Go to: https://railway.com/project/2c85abdd-e75b-498c-917e-d453c88c0c4b
- [ ] Click your **Node.js backend service** (not the database)
- [ ] Click the **"Settings"** tab in left sidebar

---

## Step 2: Configure Service Settings
Find the "Service Settings" or "Build & Deploy" section

### Set These Values:

- [ ] **Root Directory:** 
  ```
  backend/scripts
  ```
  _(exactly as shown, no quotes, no slashes at start/end)_

- [ ] **Install Command:**
  ```
  npm install
  ```

- [ ] **Build Command:**
  ```
  (leave empty or blank)
  ```

- [ ] **Start Command:**
  ```
  npm start
  ```

---

## Step 3: Save & Deploy
- [ ] Click **"Save"** or **"Update"** button
- [ ] Click **"Redeploy"** button (or wait for auto-deploy)
- [ ] Go to **"Deployments"** tab

---

## Step 4: Watch Logs
In the Deployments/Logs section, watch for:

### ✅ Success Messages:
```
✅ Installing dependencies
✅ npm install
✅ Starting application  
✅ Server running on port 8080
```

### ❌ Error Messages to Avoid:
```
❌ Cannot find module
❌ package.json not found
❌ npm: command not found
```

---

## Step 5: Get Your URL
Once deployment succeeds:

- [ ] Go to **"Settings"** → **"Networking"**
- [ ] Click **"Generate Domain"** (if not already done)
- [ ] Copy the URL (e.g., `https://capstone-backend-production.up.railway.app`)
- [ ] **Do NOT add port number** - use URL as-is

---

## Step 6: Test the Deployment
Open in browser or use curl:

### Test 1: Health Check
```
https://YOUR-RAILWAY-URL.up.railway.app/
```
**Expected:** `{"status":"Server is running"}`

- [ ] Health check works ✅

### Test 2: Products Endpoint
```
https://YOUR-RAILWAY-URL.up.railway.app/api/products
```
**Expected:** JSON array `[...]` (may be empty if no data yet)

- [ ] Products endpoint works ✅

---

## Step 7: Update Flutter App
- [ ] Open: `lib/services/railway_api_service.dart`
- [ ] Find line 12: `static const String baseUrl = 'YOUR_RAILWAY_URL_HERE';`
- [ ] Replace with: `static const String baseUrl = 'https://your-actual-url.up.railway.app';`
- [ ] Save the file
- [ ] **No trailing slash!**
- [ ] **No port number!**

---

## Step 8: Test Flutter App
```bash
flutter clean
flutter pub get
flutter run
```

- [ ] App runs without errors
- [ ] Navigate to Screen2
- [ ] See "Plant Based" section
- [ ] See "Snacks" section
- [ ] Products load successfully

---

## 🎉 Success!
If all checkboxes are checked, you're done! Your Railway backend is connected to your Flutter app.

---

## 🆘 Need Help?

**Deployment still failing?**
→ See: `RAILWAY_DEPLOYMENT_FIX.md`

**Configuration unclear?**
→ See: `RAILWAY_CONFIG_REFERENCE.md`

**Port questions?**
→ See: `RAILWAY_PORT_EXPLAINED.md`

**Full setup guide?**
→ See: `RAILWAY_SETUP.md`

---

**Current Status After This Checklist:** 🟢 Railway Deployed Successfully!

