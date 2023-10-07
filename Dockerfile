# Use an official Node.js runtime as the base image
FROM node:14

# Set the working directory in the container
WORKDIR /app

# Copy package.json and package-lock.json to the container
COPY package*.json ./

# Install project dependencies
RUN npm install

# Copy the rest of the application code to the container
COPY . .

# Build the website (assuming you have a build script)
RUN npm run build

# Expose the port your web server will run on (if applicable)
EXPOSE 80

# Start your web server (replace 'node server.js' with your actual start command)
CMD ["node", "server.js"]
