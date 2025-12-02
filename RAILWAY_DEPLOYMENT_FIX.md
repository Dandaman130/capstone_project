# 🚨 Railway Deployment Fix Guide

## Problem
Railway can't find your `index.js` file because your project structure has the backend code in `backend/scripts/` but Railway expects it at the root.

## ✅ Solution - Multiple Options

### **Option 1: Configure Railway Service Settings (RECOMMENDED - Easiest)**

1. Go to your Railway project: https://railway.com/project/2c85abdd-e75b-498c-917e-d453c88c0c4b
2. Click on your backend service
3. Go to **Settings**
4. Scroll down to **"Service Settings"** or **"Build & Deploy"**
5. Find the following fields and set them:

   **Root Directory:** `backend/scripts`
   
   **Install Command:** `npm install`
   
   **Build Command:** (leave empty or blank)
   
   **Start Command:** `npm start`

6. Click **"Deploy"** or let it auto-deploy
7. Check the logs to verify it's working

---

### **Option 2: Use Railway Configuration Files (Already Created)**

I've created these configuration files in your project root:
- ✅ `railway.json`
- ✅ `nixpacks.toml`
- ✅ `Procfile`

**Steps:**
1. Commit and push these files to your Git repository:
   ```bash
   git add railway.json nixpacks.toml Procfile
   git commit -m "Add Railway configuration files"
   git push
   ```

2. Railway will automatically detect these files and redeploy
3. Check the deployment logs

---

### **Option 3: Restructure Backend (Most Permanent)**

Move your backend to a simpler structure:

**Current structure:**
```
capstone_project/
  backend/
    scripts/
      package.json
      index.js
```

**New structure:**
```
capstone_project/
  backend/
    package.json  ← Move here
    index.js      ← Move here
    scripts/      (keep other scripts here)
```

**Steps:**
1. Move `package.json` and `index.js` from `backend/scripts/` to `backend/`
2. Update Railway settings:
   - **Root Directory:** `backend`
   - **Start Command:** `npm start`

---

## 🎯 Quick Fix Instructions (Do This Now)

### Step-by-Step Railway Settings Fix:

1. **Open Railway Dashboard**
   - Go to: https://railway.com/project/2c85abdd-e75b-498c-917e-d453c88c0c4b
   
2. **Select Your Service**
   - Click on your Node.js backend service

3. **Go to Settings**
   - Click the "Settings" tab

4. **Configure Service**
   - Look for **"Root Directory"** and set it to: `backend/scripts`
   - Look for **"Start Command"** and set it to: `npm start`
   - Look for **"Install Command"** and set it to: `npm install`

5. **Save and Redeploy**
   - Scroll down and click "Redeploy" or trigger a new deployment

6. **Watch Logs**
   - Go to the "Deployments" or "Logs" tab
   - You should see:
     ```
     > node index.js
     Server running on port 3000
     ```

---

## ✅ Verification

Once deployed successfully, test:

```bash
# Health check
curl https://your-railway-url.up.railway.app/

# Should return:
{"status":"Server is running"}
```

---

## 🆘 If It Still Doesn't Work

Check Railway logs for errors:
1. Go to your service in Railway
2. Click "Deployments" or "Logs"
3. Look for error messages

Common issues:
- **"npm: command not found"** → Railway isn't detecting Node.js
- **"Cannot find module"** → Root directory is wrong
- **Port binding error** → Make sure you're using `process.env.PORT`

---

## 📝 Files I Created

I've added these configuration files to help Railway find your backend:

1. **`railway.json`** - Railway-specific config
2. **`nixpacks.toml`** - Build configuration
3. **`Procfile`** - Alternative process file

If you're using Git, commit and push these files:
```bash
git add railway.json nixpacks.toml Procfile
git commit -m "Fix Railway deployment configuration"
git push
```

Railway will automatically pick up the changes.

---

## 🚀 After It's Working

Once you see "Server running on port..." in the logs:

1. Copy your Railway domain URL
2. Update `lib/services/railway_api_service.dart` with the URL
3. Test the endpoints
4. Run your Flutter app

---

**Recommended:** Use **Option 1** (Configure Railway Settings) - it's the fastest and doesn't require code changes!

