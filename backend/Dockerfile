# Super fast, stable base image (Bookworm is stable release)
FROM python:3.10-slim-bookworm

# Set working directory
WORKDIR /app

# Set up non-root user for Hugging Face Spaces
RUN useradd -m -u 1000 user
ENV HOME=/home/user \
    PATH=/home/user/.local/bin:$PATH

# Install system dependencies
# Fix: libgl1-mesa-glx is obsolete in newer Debian, replaced with libgl1
# Fix: Added build-essential for necessary system-level compilation of dependencies
RUN apt-get update && apt-get install -y \
    ffmpeg \
    libgl1 \
    libglib2.0-0 \
    curl \
    git \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# 1. Install optimized CPU PyTorch (HUGE speedup for free tiers)
RUN pip install --no-cache-dir torch torchvision --index-url https://download.pytorch.org/whl/cpu

# 2. Upgrade pip and build tools to avoid wheel building errors
RUN pip install --no-cache-dir --upgrade pip "setuptools<70.0.0" wheel

# 3. Install other requirements directly to avoid version conflict timeouts
RUN pip install --no-cache-dir \
    fastapi==0.110.0 \
    uvicorn==0.27.1 \
    openai-whisper \
    ffmpeg-python==0.2.0 \
    pydantic==2.6.3 \
    opencv-python-headless \
    python-multipart

# 3. Additional dependencies for Playwright
ENV PLAYWRIGHT_BROWSERS_PATH=/app/pw-browsers
RUN pip install --no-cache-dir playwright && \
    playwright install chromium && \
    playwright install-deps

# 4. (Removed SAM2 installation since we use TorchVision MobileNetV3 instead)

# Copy application code
COPY . .

# Set ownership
RUN chown -R user:user /app

# Switch to non-root
USER user

# App configuration
EXPOSE 7860
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "7860"]
