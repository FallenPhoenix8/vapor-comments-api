cd ./Frontend
npm install
npm run build
cd ..
echo "Frontend build complete."
echo "Please note, that your changes in the frontend will not be reflected in this process." 
echo "Starting server..."
watchexec -e swift -r swift run