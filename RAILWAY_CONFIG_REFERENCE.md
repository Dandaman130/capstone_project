# Railway Configuration Quick Reference

## 🎯 The Fix (Copy These Exact Values)

Go to Railway → Your Service → Settings → Service Settings

| Setting | Value |
|---------|-------|
| **Root Directory** | `backend/scripts` |
| **Install Command** | `npm install` |
| **Build Command** | _(leave empty)_ |
| **Start Command** | `npm start` |

Click **"Redeploy"** after saving.

---

## 📁 Why This Works

Your project structure:
```
capstone_project/              ← Root (where Railway starts)
├── lib/                       ← Flutter app
├── backend/
│   └── scripts/              ← Your backend code is HERE
│       ├── package.json      ← Node.js config
│       ├── index.js          ← Your server
│       └── ...
```

**Problem:** Railway looks at root, but your backend is in `backend/scripts/`

**Solution:** Set **Root Directory** to `backend/scripts/` so Railway:
1. Changes to `backend/scripts/` directory
2. Runs `npm install` there
3. Runs `npm start` (which runs `node index.js`)

---

## ✅ Success Indicators

### In Railway Logs You'll See:
```
=== Installing dependencies ===
npm install

=== Starting application ===
npm start

> scripts@1.0.0 start
> node index.js

Server running on port 8080   ← SUCCESS!
```

### What You WON'T See (errors):
```
❌ Error: Cannot find module '/app/backend/scripts/index.js'
❌ npm: command not found
❌ package.json not found
```

---

## 🔍 Where to Find These Settings

### Visual Guide:

```
Railway Dashboard
  ↓
Click Your Service (the Node.js one)
  ↓
Click "Settings" Tab (left sidebar)
  ↓
Scroll down to "Service Settings" or "Build & Deploy"
  ↓
Fill in the values from the table above
  ↓
Scroll to bottom → Click "Redeploy"
```

---

## 🧪 Test After Deployment

Once logs show "Server running on port...":

**1. Test in browser:**
```
https://your-railway-url.up.railway.app/
```

**Expected response:**
```json
{"status":"Server is running"}
```

**2. Test products endpoint:**
```
https://your-railway-url.up.railway.app/api/products
```

**Expected:** JSON array of products (or empty array `[]` if DB is empty)

---

## 🆘 Still Having Issues?

### Check These:

1. **✅ Root Directory is set correctly:** `backend/scripts` (no leading or trailing slashes)
2. **✅ DATABASE_URL is set:** Go to Variables tab, should see `DATABASE_URL` automatically set by Railway Postgres
3. **✅ Service is linked to database:** Your Node.js service should be connected to PostgreSQL
4. **✅ Files exist:** Make sure `backend/scripts/index.js` and `package.json` are in your Git repo

### View Full Logs:
1. Railway → Your Service → "Deployments" tab
2. Click the latest deployment
3. Read the full build and runtime logs

---

## 📋 Alternative: Configuration Files

I've also created these files as backup:
- `railway.json` - Railway config
- `nixpacks.toml` - Build config  
- `Procfile` - Process file

If Railway settings don't work, commit and push these files to your Git repo.

---

**TL;DR:** Set **Root Directory** to `backend/scripts` in Railway Settings → Redeploy → Watch logs for success! 🚀

