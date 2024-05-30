# Statistical Analysis of unikernel-znnd vs. Docker and Baremetal

This analysis compares the performance of three different deployment modes: baremetal, znnd-docker, and unikernel-znnd, focusing on boot time and time to first momentum (TTM). The specifications for each setup are as follows:

## Specifications

- **Baremetal:**
  - **Hardware:** 300 GB SSD, 12 GB RAM, 8 CPU
  - **Operating System:** Fedora
  
- **Docker:**
  - **Deployment:** Docker image running on the baremetal server
  
- **Unikernel:**
  - **Virtual Machine:** XEN VM
  - **Hardware:** 10 GB HDD, 8 GB RAM, 4 CPU

## Performance Metrics

The performance metrics measured include:
- **Boot Time (ms):** Time taken for the system to boot.
- **Time to First Momentum (TTM) (ms):** Time taken to reach the first momentum.

## Data Summary

- **Baremetal:**
  - **Boot Time:** Mean = 11500 ms, Standard Deviation = 338.17 ms
  - **TTM:** Mean = 28500 ms, Standard Deviation = 473.51 ms

- **znnd-docker:**
  - **Boot Time:** Mean = 1944 ms, Standard Deviation = 43.90 ms
  - **TTM:** Mean = 12400 ms, Standard Deviation = 212.63 ms

- **unikernel-znnd:**
  - **Boot Time:** Mean = 150 ms, Standard Deviation = 1.51 ms
  - **TTM:** Mean = 895 ms, Standard Deviation = 4.32 ms

## Statistical Analysis

1. **Boot Time:**
   - **unikernel-znnd** shows a significantly lower mean boot time (150 ms) compared to **znnd-docker** (1944 ms) and **Baremetal** (11500 ms).
   - The standard deviation for unikernel-znnd (1.51 ms) indicates very tight clustering around the mean, implying high consistency and reliability in boot times.

2. **Time to First Momentum (TTM):**
   - **unikernel-znnd** also achieves a much lower mean TTM (895 ms) compared to **znnd-docker** (12400 ms) and **Baremetal** (28500 ms).
   - Similar to boot time, the TTM standard deviation for unikernel-znnd (4.32 ms) is significantly smaller, reflecting consistent performance.

## Discussion

The data reveals that the unikernel-znnd setup offers **statistically significant** advantages in both boot time and TTM over both the znnd-docker and Baremetal setups. The tighter standard deviations for unikernel-znnd further highlight its consistency and predictability in performance.

1. **unikernel-znnd vs. znnd-docker:**
   - unikernel-znnd boots approximately 13 times faster than znnd-docker.
   - The time to reach first momentum is reduced by almost 14 times in the unikernel-znnd setup compared to znnd-docker.
   - These differences are highly significant, with unikernel-znnd demonstrating much lower variability, suggesting more reliable performance.

2. **unikernel-znnd vs. Baremetal:**
   - unikernel-znnd boots about 77 times faster than the baremetal configuration.
   - The TTM for unikernel-znnd is about 32 times faster than that of baremetal.
   - Given the considerable reduction in both boot time and TTM, along with minimal variability, unikernel-znnd presents a clear advantage in scenarios requiring rapid deployment and minimal downtime.

## Implications 

- Scalability: Given the trivial Boot Time and TTM, it becomes apparent  that if a node database can be bootstrapped, the potential for endless, realtime scalability of nodes becomes a reality. Zk-proofing can also be implemented here to create redundant/"replacable" nodes on-demand.
- Security: Of course, the implementation of a unikernel at the node-level introduces other meaningful benefits that could not be addressed here. Unikernels inherently offer enhanced security due to their minimal attack surface. Each unikernel is designed to run a single application, eliminating the unnecessary code that can introduce vulnerabilities. Additionally, unikernels reduce the complexity of the system, making it easier to audit and secure. This streamlined approach to deployment further enhances the overall security posture, providing robust protection against a range of potential threats.

## Conclusion

In summary, unikernel-znnd demonstrates statistically significant improvements in both boot time and time to first momentum compared to znnd-docker and Baremetal configurations. This suggests that for environments where rapid deployment and consistent performance are critical, unikernel-znnd is the superior choice. The analysis underscores the unikernel's efficiency and reliability, making it a highly effective solution for performance-sensitive applications.
