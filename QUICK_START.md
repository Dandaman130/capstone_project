# 🚀 Quick Start Checklist

## Step 0: Fix Railway Deployment First! 🔧

**IMPORTANT:** Before getting your URL, make sure Railway can deploy your backend correctly.

### Configure Railway Service Settings:

1. [ ] Go to https://railway.com/project/2c85abdd-e75b-498c-917e-d453c88c0c4b
2. [ ] Click on your **backend service** (Node.js app)
3. [ ] Go to **Settings** tab
4. [ ] Scroll to **"Service Settings"** section and configure:
   - **Root Directory:** `backend/scripts`
   - **Install Command:** `npm install`
   - **Start Command:** `npm start`
5. [ ] Click **"Redeploy"** or trigger a new deployment
6. [ ] Go to **"Deployments"** tab and watch the logs
7. [ ] Wait for: `Server running on port...` ✅

**If deployment fails, see:** `RAILWAY_DEPLOYMENT_FIX.md` for detailed troubleshooting.

## Step 1: Get Your Railway URL ⚡

1. [ ] Go to https://railway.com/project/2c85abdd-e75b-498c-917e-d453c88c0c4b
2. [ ] Click on your backend service (Node.js app)
3. [ ] Go to **Settings** → **Networking**
4. [ ] Click **"Generate Domain"** (if needed)
5. [ ] **Copy your deployment URL** (e.g., `https://capstone-backend-abc123.up.railway.app`)

   **⚠️ IMPORTANT:** 
   - Railway will ask "What port is it listening to?" → Your code uses `process.env.PORT` so Railway handles this automatically
   - Just use the domain URL as-is: `https://your-app.up.railway.app`
   - **DO NOT add** `:3000` or any port number to the URL
   - Railway's reverse proxy automatically routes to your app's port

## Step 2: Update Flutter App 📱

1. [ ] Open: `lib/services/railway_api_service.dart`
2. [ ] Find line 12: `static const String baseUrl = 'YOUR_RAILWAY_URL_HERE';`
3. [ ] Replace with your URL: `static const String baseUrl = 'https://your-url.up.railway.app';`
4. [ ] **IMPORTANT:** No trailing slash!
5. [ ] Save the file

## Step 3: Test Your Backend 🧪

Test these URLs in your browser (replace with your actual URL):

- [ ] Health Check: `https://your-url.up.railway.app/`
  - Should return: `{"status":"Server is running"}`

- [ ] All Products: `https://your-url.up.railway.app/api/products`
  - Should return: JSON array of products

- [ ] Plant Based: `https://your-url.up.railway.app/api/categories/plant%20based`
  - Should return: Products with "plant based" in categories

- [ ] Snacks: `https://your-url.up.railway.app/api/categories/snacks`
  - Should return: Products with "snacks" in categories

## Step 4: Run Your Flutter App 🏃

```bash
flutter clean
flutter pub get
flutter run
```

## Step 5: Verify Screen2 ✅

Navigate to Screen2 and check:

- [ ] Search bar appears at top
- [ ] "Plant Based" section appears
- [ ] "Snacks" section appears
- [ ] Products display with image placeholders and names
- [ ] Horizontal scrolling works
- [ ] Pull-to-refresh works
- [ ] Tapping products shows snackbar

## 🆘 Troubleshooting

**❌ Categories not showing:**
- Check Railway logs for errors
- Verify products in database have categories "plant based" or "snacks"
- Check Flutter debug console for API errors

**❌ "Server is running" but no products:**
- Run the import script to populate database
- Check database has products with the categories field populated

**❌ Network error in Flutter:**
- Verify Railway URL is correct
- Make sure Railway service is deployed and running
- Check internet connection

**❌ Build errors:**
```bash
flutter clean
flutter pub get
flutter run
```

## 📝 What You Should See

### Screen2 Layout:
```
┌─────────────────────────┐
│   🔍 Search products... │  ← Search bar
├─────────────────────────┤
│                         │
│ Plant Based    View All │  ← Category header
│ ┌────┐ ┌────┐ ┌────┐   │
│ │ 📦 │ │ 📦 │ │ 📦 │ → │  ← Horizontal scroll
│ │Name│ │Name│ │Name│   │
│ └────┘ └────┘ └────┘   │
├─────────────────────────┤
│ Snacks         View All │  ← Category header
│ ┌────┐ ┌────┐ ┌────┐   │
│ │ 📦 │ │ 📦 │ │ 📦 │ → │  ← Horizontal scroll
│ │Name│ │Name│ │Name│   │
│ └────┘ └────┘ └────┘   │
└─────────────────────────┘
```

## 🎯 Success Criteria

You're all set when:
- ✅ Railway URL is added to `railway_api_service.dart`
- ✅ Backend endpoints return data
- ✅ Screen2 displays "Plant Based" and "Snacks" sections
- ✅ Products show with names under placeholder images
- ✅ Horizontal scrolling works smoothly

## 📚 Need More Help?

- Detailed setup: `RAILWAY_SETUP.md`
- Implementation details: `IMPLEMENTATION_SUMMARY.md`
- Backend code: `backend/scripts/index.js`
- Flutter service: `lib/services/railway_api_service.dart`

---

**Current Status:** Ready to add Railway URL and test! 🎉

