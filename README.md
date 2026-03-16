# ROS 2 Interface

## Subscriptions

| Topic | Type | Description |
|:------|:-----|:------------|
| `/steering_command` | `std_msgs/msg/Float32` | Desired steering angle setpoint (degrees) |
| `/throttle` | `std_msgs/msg/Float32` | Throttle command in range **[-1.0, 1.0]** (maps to 1000–2000 µs ESC pulse) |

## Publications

| Topic | Type | Rate | Description |
|:------|:-----|:----:|:------------|
| `/steering_angle` | `std_msgs/msg/Float32` | 20 Hz | Filtered steering angle feedback from the ADC sensor (degrees) |

# RUN car interface

```bash
./run_micro_ros_agent.sh
```

# Connnect to the vehicle

1. Make an hotspot or wifi with the following name
    - SSID : asurt
    - Pass : 12345678
2. get the ip of the pi connected
3. connect to the pi via ssh 
    ```bash
    ssh f1_pi@<IP>
    ```