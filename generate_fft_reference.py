import numpy as np
import matplotlib.pyplot as plt
import os

# Parameters matching the SystemVerilog implementation
SAMPLE_PER_MS = 16
WINDOWSIZE_MS = 32
WINDOWSTEP = 10 * SAMPLE_PER_MS  # 10ms step
REQUIRED_FRAMES = 97
WINDOWSIZE = SAMPLE_PER_MS * WINDOWSIZE_MS

# Generate test signals: a sum of sine waves
def generate_test_signal(num_samples, fs=16000):
    t = np.arange(num_samples) / fs
    # Create a signal with multiple frequency components
    signal = np.zeros(num_samples)
    
    # Add sine waves at different frequencies
    signal += 1000 * np.sin(2 * np.pi * 500 * t)   # 500 Hz
    signal += 500 * np.sin(2 * np.pi * 1000 * t)   # 1000 Hz
    signal += 250 * np.sin(2 * np.pi * 2000 * t)   # 2000 Hz
    
    # Add some noise
    noise = np.random.normal(0, 50, num_samples)
    signal += noise
    
    # Convert to integer to match hardware implementation
    signal = np.int16(signal)
    return signal

# Generate FFT reference data
def generate_fft_reference(signal):
    frames = []
    fft_results = []
    
    # Process frames with overlap as in the hardware
    for i in range(REQUIRED_FRAMES):
        start_idx = i * WINDOWSTEP
        end_idx = start_idx + WINDOWSIZE
        
        if end_idx > len(signal):
            # Zero-pad if we run out of signal
            frame = np.zeros(WINDOWSIZE)
            frame[:len(signal) - start_idx] = signal[start_idx:]
        else:
            frame = signal[start_idx:end_idx]
        
        frames.append(frame)
        
        # Apply Hamming window (optional, uncomment if your hardware applies windowing)
        # frame = frame * np.hamming(WINDOWSIZE)
        
        # Compute FFT
        fft_result = np.fft.fft(frame)
        
        # Compute magnitude spectrum (similar to hardware)
        magnitude = np.abs(fft_result)
        
        # Only keep the first 257 elements (DC to Nyquist)
        magnitude = magnitude[:257]
        
        fft_results.append(magnitude)
    
    return frames, fft_results

# Create output directory if it doesn't exist
output_dir = "fft_reference_data"
os.makedirs(output_dir, exist_ok=True)

# Generate enough samples for all required frames
total_samples_needed = WINDOWSIZE + WINDOWSTEP * (REQUIRED_FRAMES - 1)
test_signal = generate_test_signal(total_samples_needed)

# Generate reference FFT data
frames, fft_results = generate_fft_reference(test_signal)

# Save input signal in format suitable for testbench
with open(f"{output_dir}/input_signal.txt", "w") as f:
    for sample in test_signal:
        # Convert to 16-bit signed representation
        f.write(f"{sample & 0xFFFF:04x}\n")

# Save FFT reference results
with open(f"{output_dir}/fft_reference.txt", "w") as f:
    for frame_idx, frame_result in enumerate(fft_results):
        for i, mag in enumerate(frame_result):
            # Convert magnitude to fixed-point representation
            # Scale the magnitude to match hardware implementation
            # Assuming 16-bit fixed-point representation
            mag_fixed = int(mag) & 0xFFFF
            f.write(f"{frame_idx},{i},{mag_fixed:04x}\n")

# Plot example FFT for visual reference
plt.figure(figsize=(12, 6))
plt.subplot(2, 1, 1)
plt.plot(frames[0])
plt.title("Example Input Frame (Time Domain)")

plt.subplot(2, 1, 2)
plt.plot(fft_results[0])
plt.title("Example FFT Magnitude Spectrum")
plt.xlabel("Frequency Bin")
plt.tight_layout()
plt.savefig(f"{output_dir}/example_fft.png")
plt.close()

print(f"Reference data generated and saved to {output_dir}/")
print(f"Generated {REQUIRED_FRAMES} frames of FFT reference data.")
print(f"Each frame has {WINDOWSIZE} samples with {WINDOWSTEP} sample step between frames.")
print(f"First 257 frequency bins saved for each frame.")
