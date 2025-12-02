# Railway Backend Setup Guide

## 🚂 Getting Your Railway Deployment URL

Your Railway project dashboard URL is:
`https://railway.com/project/2c85abdd-e75b-498c-917e-d453c88c0c4b`

To get your **actual deployment URL** (needed for the Flutter app):

1. Go to your Railway project dashboard
2. Click on your **backend service** (the one running your Node.js server)
3. Go to the **"Settings"** tab
4. Scroll down to **"Networking"** section
5. Click **"Generate Domain"** if you haven't already
6. Copy the generated domain (it will look like: `https://your-app-name.up.railway.app`)

**About the Port:**
- Railway may ask "What port is it listening to?"
- Your code already uses `process.env.PORT` (see line 5 in `backend/scripts/index.js`)
- Railway automatically sets this environment variable
- **Just use the domain URL without any port number**
- Example: `https://your-app.up.railway.app` (NOT `https://your-app.up.railway.app:3000`)

## 📝 Steps to Complete Setup

### Step 1: Deploy Your Backend to Railway

1. Make sure your backend code is in a Git repository
2. In Railway, connect your GitHub repository
3. Railway will auto-detect the `backend/scripts` folder
4. Set the following environment variables in Railway:
   - `DATABASE_URL` (automatically set when you add PostgreSQL)
   - `PORT` (Railway sets this automatically)

### Step 2: Update Flutter App with Railway URL

Once you have your Railway deployment URL:

1. Open: `lib/services/railway_api_service.dart`
2. Find the line: `static const String baseUrl = 'YOUR_RAILWAY_URL_HERE';`
3. Replace with your actual URL: `static const String baseUrl = 'https://your-app-name.up.railway.app';`
4. Save the file

### Step 3: Test Your Backend

Test that your backend is working:

```bash
# Health check
curl https://your-app-name.up.railway.app/

# Get all products
curl https://your-app-name.up.railway.app/api/products

# Get products by category
curl https://your-app-name.up.railway.app/api/categories/plant%20based

# Search products
curl https://your-app-name.up.railway.app/api/search?q=coca
```

## 🗄️ Database Setup

Your database should have this schema:

```sql
CREATE TABLE IF NOT EXISTS products (
  id SERIAL PRIMARY KEY,
  name TEXT,
  categories TEXT,
  ingredients TEXT,
  barcode TEXT UNIQUE,
  image_url TEXT
);
```

To import products, run the import script with your DATABASE_URL:

```bash
cd backend/scripts
npm install
DATABASE_URL="your_railway_db_url" node import_products.js
```

## 🎯 API Endpoints Available

- `GET /` - Health check
- `GET /api/products` - Get all products (limit: 100)
- `GET /api/products/:barcode` - Get product by barcode
- `GET /api/search?q=query` - Search products by name
- `GET /api/categories/:category` - Get products by category
- `GET /api/categories-batch?categories=cat1,cat2&limit=20` - Get multiple categories at once

## 📱 Flutter App Integration

The app is now set up with:

1. **Product Model** (`lib/models/product.dart`) - Matches your database schema
2. **Railway API Service** (`lib/services/railway_api_service.dart`) - Handles all API calls
3. **Screen2 Updated** (`lib/screens/screen2.dart`) - Displays products by categories

### Categories Currently Displayed:
- Plant Based
- Snacks

### Features:
- Horizontal scrolling product cards
- Pull to refresh
- Search functionality
- "Recently Scanned" section for cached products

## 🔧 Troubleshooting

**If products don't load:**
1. Check that Railway URL is correct in `railway_api_service.dart`
2. Verify backend is deployed and running on Railway
3. Check Railway logs for errors
4. Test API endpoints with curl or Postman

**If categories are empty:**
1. Make sure products in database have the correct categories
2. Categories are matched using `ILIKE` (case-insensitive)
3. Categories should contain "plant based" or "snacks" in the categories field

## 🚀 Next Steps

1. Get your Railway deployment URL
2. Update `railway_api_service.dart` with the URL
3. Test the app
4. Add more categories as needed
5. Implement product detail screen
6. Add Hive for local caching

