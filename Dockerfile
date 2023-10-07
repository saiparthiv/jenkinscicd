# Use an official Nginx image as the base image
FROM nginx:alpine

# Copy your static website files to the Nginx web root directory
COPY . /usr/share/nginx/html

# Expose port 80 for HTTP
EXPOSE 80

# Start the Nginx server in the foreground
CMD ["nginx", "-g", "daemon off;"]

