echo "This script will build the frontend, then run the backend in development mode. watchexec must be installed on your system."
echo "Building frontend..."
cd ./Frontend
npm install
npm run build
cd ..
echo "Frontend build complete."
echo "Please note, that your changes in the frontend will not be reflected in this process." 
echo "Starting server..."
watchexec -e swift -r swift run