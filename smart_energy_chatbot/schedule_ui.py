import tkinter as tk
from schedule_module import weekly_schedule, estimate_savings

# CREATE WINDOW
root = tk.Tk()
root.title("Schedule Optimizer")
root.geometry("400x500")
root.configure(bg="#ECE5DD")

# HEADER
header = tk.Label(
    root,
    text="📅 Energy Schedule Optimizer",
    bg="#075E54",
    fg="white",
    font=("Arial", 14, "bold"),
    pady=10
)
header.pack(fill=tk.X)

# SCHEDULE DISPLAY
frame = tk.Frame(root, bg="#ECE5DD")
frame.pack(pady=10)

schedule = weekly_schedule()

for day, task in schedule.items():
    label = tk.Label(
        frame,
        text=f"{day}: {task}",
        font=("Arial", 11),
        bg="white",
        anchor="w",
        padx=10,
        pady=5,
        width=40
    )
    label.pack(pady=3)

# SAVING DISPLAY
saving = estimate_savings(200)

saving_label = tk.Label(
    root,
    text=f"💰 Estimated Monthly Saving: Rs. {saving}",
    font=("Arial", 12, "bold"),
    bg="#ECE5DD",
    fg="green"
)
saving_label.pack(pady=15)

# REMINDER BUTTON
def show_reminder():
    reminder_label.config(text="🔔 Best time to use appliances is at night!")

btn = tk.Button(
    root,
    text="Show Reminder",
    command=show_reminder,
    bg="#25D366",
    fg="white",
    padx=10
)
btn.pack(pady=10)

reminder_label = tk.Label(root, text="", bg="#ECE5DD", font=("Arial", 11))
reminder_label.pack()

root.mainloop()