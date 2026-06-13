# OpportunityFlow AI — Deployment Guide 🚀

This guide explains how to deploy the OpportunityFlow AI platform to production.

---

## 🖥 1. Deploying the FastAPI Backend (Render)

Render is the recommended hosting platform for the backend as it fully supports Python web servers, databases, and environment variables.

### Steps to Deploy on Render:
1. Go to the [Render Dashboard](https://dashboard.render.com/) and log in.
2. Click **New +** at the top right and select **Web Service**.
3. Connect your GitHub account and select your repository: `OpportunityFlow-AI---IQOO-Skylrk-`.
4. Configure the Web Service settings:
   * **Name**: `opportunityflow-api`
   * **Root Directory**: `backend`
   * **Runtime**: `Python`
   * **Branch**: `main`
   * **Build Command**: `pip install -r requirements.txt`
   * **Start Command**: `uvicorn main:app --host 0.0.0.0 --port $PORT`
5. Scroll down and click **Advanced** to add **Environment Variables**:
   * `GEMINI_API_KEY`: Your Google Gemini API Key.
   * `DEBUG`: `false`
6. Click **Create Web Service**. 
7. Once deployed, Render will provide a public URL for your backend (e.g., `https://opportunityflow-api.onrender.com`).

---

## 🎨 2. Deploying the Flutter Frontend

Since your frontend is built with Flutter Web, you can deploy it as a static site on **Render Static Sites**, **Vercel**, **Netlify**, or **GitHub Pages**.

### Update Deployed Backend URL:
We have configured `api_service.dart` to automatically detect production vs local environments.
* If you deployed your backend to a custom Render URL different from `https://opportunityflow-api.onrender.com`, open [api_service.dart](file:///frontend/lib/core/services/api_service.dart) and update line 12 with your actual Render URL:
  ```dart
  return 'https://<your-render-app-name>.onrender.com/api';
  ```

---

### Option A: Deploy via GitHub Pages (Fully Automated)

You can use GitHub Actions to build and deploy your Flutter web app automatically on every commit.

1. Create a GitHub Actions workflow in the root of your project: `.github/workflows/deploy.yml` with the following configuration:
   ```yaml
   name: Deploy Flutter Web to GitHub Pages

   on:
     push:
       branches:
         - main

   jobs:
     build-and-deploy:
       runs-on: ubuntu-latest
       steps:
         - name: Checkout repository
           uses: actions/checkout@v3

         - name: Set up Flutter
           uses: subosito/flutter-action@v2
           with:
             channel: 'stable'

         - name: Install dependencies
           run: |
             cd frontend
             flutter pub get

         - name: Build Flutter Web
           run: |
             cd frontend
             flutter build web --release --base-href "/OpportunityFlow-AI---IQOO-Skylrk-/"

         - name: Deploy to GitHub Pages
           uses: JamesIves/github-pages-deploy-action@v4
           with:
             folder: frontend/build/web
             branch: gh-pages
   ```
2. Enable GitHub Pages in your repository:
   * Go to **Settings** -> **Pages**.
   * Under **Build and deployment**, set the Source to **Deploy from a branch**.
   * Set Branch to **`gh-pages`** and folder to `/ (root)`.
3. Commit and push: The GitHub Action will build your Flutter Web app and deploy it automatically.

---

### Option B: Deploy via Vercel CLI (Fastest Manual Deploy)

If you prefer to deploy the static build files manually:
1. Build the release version of the Flutter Web app locally:
   ```bash
   cd frontend
   flutter build web --release
   ```
2. Install the Vercel CLI:
   ```bash
   npm install -g vercel
   ```
3. Run Vercel in the build output directory:
   ```bash
   cd build/web
   vercel --prod
   ```
   Follow the CLI prompts to deploy the static app in seconds.
