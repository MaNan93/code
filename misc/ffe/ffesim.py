#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
ffesim.py

PCIe Gen6 Tx FFE / PAM4 Visualizer

Dependencies:
    PyQt5
    numpy
    matplotlib

Install:
    pip install PyQt5 numpy matplotlib

Run:
    python ffesim.py

Notes:
    - This is an educational visualization tool.
    - It is NOT a PCI-SIG compliance simulator.
    - The channel model is simplified.
"""

import sys
import numpy as np

from PyQt5.QtCore import Qt
from PyQt5.QtWidgets import (
    QApplication,
    QMainWindow,
    QWidget,
    QVBoxLayout,
    QHBoxLayout,
    QGridLayout,
    QLabel,
    QSlider,
    QPushButton,
    QGroupBox,
    QSpinBox,
    QCheckBox,
)

from matplotlib.backends.backend_qt5agg import FigureCanvasQTAgg as FigureCanvas
from matplotlib.figure import Figure


# ============================================================
# Plot canvas
# ============================================================

class PlotCanvas(FigureCanvas):

    def __init__(self):
        self.fig = Figure(figsize=(12, 9))
        super().__init__(self.fig)

        self.ax_original = self.fig.add_subplot(4, 1, 1)
        self.ax_ffe = self.fig.add_subplot(4, 1, 2)
        self.ax_channel = self.fig.add_subplot(4, 1, 3)
        self.ax_eye = self.fig.add_subplot(4, 1, 4)

        self.fig.tight_layout()


# ============================================================
# Main window
# ============================================================

class MainWindow(QMainWindow):

    def __init__(self):
        super().__init__()

        self.setWindowTitle("PCIe Gen6 Tx FFE / PAM4 Visualizer")
        self.resize(1450, 1000)

        # ----------------------------------------------------
        # Simulation parameters
        # ----------------------------------------------------

        self.samples_per_ui = 32
        self.num_symbols = 100

        self.rng = np.random.default_rng(1234)

        self.symbols = self.generate_pam4()

        # ----------------------------------------------------
        # Initial FFE coefficients
        # These are magnitude values for visualization.
        # ----------------------------------------------------

        self.cm2 = 2
        self.cm1 = 5
        self.c0 = 50
        self.cp1 = 6

        self.build_ui()

        self.update_plot()

    # ========================================================
    # PAM4 generator
    # ========================================================

    def generate_pam4(self):

        levels = np.array([
            -3.0,
            -1.0,
             1.0,
             3.0,
        ])

        return self.rng.choice(
            levels,
            size=self.num_symbols
        )

    # ========================================================
    # GUI
    # ========================================================

    def build_ui(self):

        root = QWidget()
        self.setCentralWidget(root)

        main_layout = QVBoxLayout(root)

        top_layout = QHBoxLayout()
        main_layout.addLayout(top_layout)

        # ----------------------------------------------------
        # FFE control box
        # ----------------------------------------------------

        ffe_box = QGroupBox("Tx FFE Coefficients")

        ffe_layout = QGridLayout(ffe_box)

        self.sliders = {}
        self.value_labels = {}

        params = [
            ("C-2", 0, 7, self.cm2),
            ("C-1", 0, 15, self.cm1),
            ("C0",  0, 63, self.c0),
            ("C+1", 0, 31, self.cp1),
        ]

        for row, (name, minimum, maximum, value) in enumerate(params):

            label = QLabel(name)

            slider = QSlider(Qt.Horizontal)
            slider.setMinimum(minimum)
            slider.setMaximum(maximum)
            slider.setValue(value)

            value_label = QLabel(str(value))
            value_label.setMinimumWidth(40)

            slider.valueChanged.connect(
                lambda v, n=name: self.ffe_changed(n, v)
            )

            ffe_layout.addWidget(label, row, 0)
            ffe_layout.addWidget(slider, row, 1)
            ffe_layout.addWidget(value_label, row, 2)

            self.sliders[name] = slider
            self.value_labels[name] = value_label

        top_layout.addWidget(ffe_box, stretch=2)

        # ----------------------------------------------------
        # Channel controls
        # ----------------------------------------------------

        channel_box = QGroupBox("Channel / Simulation")

        channel_layout = QGridLayout(channel_box)

        channel_layout.addWidget(
            QLabel("Channel strength"),
            0,
            0
        )

        self.channel_slider = QSlider(Qt.Horizontal)
        self.channel_slider.setMinimum(0)
        self.channel_slider.setMaximum(100)
        self.channel_slider.setValue(65)

        self.channel_slider.valueChanged.connect(
            self.update_plot
        )

        self.channel_value_label = QLabel("0.65")

        channel_layout.addWidget(
            self.channel_slider,
            0,
            1
        )

        channel_layout.addWidget(
            self.channel_value_label,
            0,
            2
        )

        # ----------------------------------------------------
        # Symbol count
        # ----------------------------------------------------

        channel_layout.addWidget(
            QLabel("Number of symbols"),
            1,
            0
        )

        self.symbol_spin = QSpinBox()
        self.symbol_spin.setMinimum(20)
        self.symbol_spin.setMaximum(500)
        self.symbol_spin.setValue(self.num_symbols)

        self.symbol_spin.valueChanged.connect(
            self.symbol_count_changed
        )

        channel_layout.addWidget(
            self.symbol_spin,
            1,
            1
        )

        # ----------------------------------------------------
        # Enable channel
        # ----------------------------------------------------

        self.channel_enable = QCheckBox("Enable channel")
        self.channel_enable.setChecked(True)

        self.channel_enable.stateChanged.connect(
            self.update_plot
        )

        channel_layout.addWidget(
            self.channel_enable,
            2,
            0,
            1,
            2
        )

        top_layout.addWidget(
            channel_box,
            stretch=2
        )

        # ----------------------------------------------------
        # Action buttons
        # ----------------------------------------------------

        action_box = QGroupBox("Actions")

        action_layout = QVBoxLayout(action_box)

        random_btn = QPushButton("Randomize PAM4")
        random_btn.clicked.connect(
            self.randomize_symbols
        )

        reset_btn = QPushButton("Reset FFE")
        reset_btn.clicked.connect(
            self.reset_ffe
        )

        strong_eq_btn = QPushButton("Strong EQ Demo")
        strong_eq_btn.clicked.connect(
            self.strong_eq_demo
        )

        no_eq_btn = QPushButton("Disable FFE")
        no_eq_btn.clicked.connect(
            self.disable_ffe
        )

        action_layout.addWidget(random_btn)
        action_layout.addWidget(reset_btn)
        action_layout.addWidget(strong_eq_btn)
        action_layout.addWidget(no_eq_btn)

        top_layout.addWidget(
            action_box,
            stretch=1
        )

        # ----------------------------------------------------
        # Formula
        # ----------------------------------------------------

        self.formula_label = QLabel()

        self.formula_label.setAlignment(
            Qt.AlignCenter
        )

        self.formula_label.setStyleSheet(
            "font-size: 15px; "
            "font-weight: bold; "
            "padding: 6px;"
        )

        main_layout.addWidget(
            self.formula_label
        )

        # ----------------------------------------------------
        # Matplotlib
        # ----------------------------------------------------

        self.canvas = PlotCanvas()

        main_layout.addWidget(
            self.canvas,
            stretch=1
        )

        # ----------------------------------------------------
        # Status bar text
        # ----------------------------------------------------

        self.status_label = QLabel()

        self.status_label.setStyleSheet(
            "padding: 4px;"
        )

        main_layout.addWidget(
            self.status_label
        )

    # ========================================================
    # FFE model
    # ========================================================

    def get_ffe_kernel(self):
        """
        Educational 4-tap Tx FFE model.

        Displayed coefficients are positive magnitudes:
            C-2
            C-1
            C0
            C+1

        For visualization:
            pre-cursor  -> negative
            main cursor -> positive
            post-cursor -> negative

        Kernel:
            [-C-2, -C-1, C0, -C+1]
        """

        total = (
            self.cm2 +
            self.cm1 +
            self.c0 +
            self.cp1
        )

        if total == 0:
            return np.array([
                0.0,
                0.0,
                1.0,
                0.0
            ])

        return np.array([
            -self.cm2 / total,
            -self.cm1 / total,
             self.c0  / total,
            -self.cp1 / total,
        ])

    def apply_ffe(self):

        kernel = self.get_ffe_kernel()

        symbol_rate_output = np.convolve(
            self.symbols,
            kernel,
            mode="same"
        )

        waveform = np.repeat(
            symbol_rate_output,
            self.samples_per_ui
        )

        return waveform

    # ========================================================
    # Original PAM4 waveform
    # ========================================================

    def original_waveform(self):

        return np.repeat(
            self.symbols,
            self.samples_per_ui
        )

    # ========================================================
    # Channel model
    # ========================================================

    def get_channel_kernel(self):
        """
        Very simple synthetic channel.

        It mainly produces post-cursor ISI.

        This is NOT a real PCIe channel.
        """

        strength = (
            self.channel_slider.value()
            / 100.0
        )

        main = 1.0 - 0.35 * strength

        post1 = 0.32 * strength
        post2 = 0.16 * strength
        post3 = 0.07 * strength

        kernel = np.array([
            main,
            post1,
            post2,
            post3
        ])

        kernel = kernel / np.sum(kernel)

        return kernel

    def apply_channel(self, waveform):

        if not self.channel_enable.isChecked():
            return waveform.copy()

        kernel = self.get_channel_kernel()

        rx = np.convolve(
            waveform,
            kernel,
            mode="same"
        )

        return rx

    # ========================================================
    # Eye diagram
    # ========================================================

    def draw_eye(self, ax, waveform):

        ax.clear()

        span = (
            2 *
            self.samples_per_ui
        )

        start = (
            4 *
            self.samples_per_ui
        )

        end = (
            len(waveform)
            -
            4 * self.samples_per_ui
            -
            span
        )

        if end <= start:
            return

        num_trace = min(
            180,
            (
                end - start
            )
            //
            self.samples_per_ui
        )

        for i in range(num_trace):

            index = (
                start
                +
                i * self.samples_per_ui
            )

            segment = waveform[
                index :
                index + span
            ]

            if len(segment) != span:
                continue

            x = np.linspace(
                0,
                2,
                span
            )

            ax.plot(
                x,
                segment,
                linewidth=0.7,
                alpha=0.28
            )

        ax.set_title(
            "4. PAM4 Eye Diagram"
        )

        ax.set_xlabel(
            "UI"
        )

        ax.set_ylabel(
            "Amplitude"
        )

        ax.set_xlim(
            0,
            2
        )

        ax.grid(
            True,
            alpha=0.25
        )

    # ========================================================
    # Plot update
    # ========================================================

    def update_plot(self):

        self.channel_value_label.setText(
            f"{self.channel_slider.value() / 100.0:.2f}"
        )

        self.formula_label.setText(
            f"y[n] = "
            f"-{self.cm2}·x[n-2] "
            f"- {self.cm1}·x[n-1] "
            f"+ {self.c0}·x[n] "
            f"- {self.cp1}·x[n+1]"
        )

        original = self.original_waveform()

        tx_ffe = self.apply_ffe()

        rx = self.apply_channel(
            tx_ffe
        )

        ax1 = self.canvas.ax_original
        ax2 = self.canvas.ax_ffe
        ax3 = self.canvas.ax_channel
        ax4 = self.canvas.ax_eye

        ax1.clear()
        ax2.clear()
        ax3.clear()
        ax4.clear()

        display_ui = min(
            self.num_symbols,
            40
        )

        # ----------------------------------------------------
        # Original PAM4
        # ----------------------------------------------------

        x1 = (
            np.arange(
                len(original)
            )
            /
            self.samples_per_ui
        )

        ax1.plot(
            x1,
            original,
            linewidth=1.2
        )

        ax1.set_title(
            "1. Original PAM4"
        )

        ax1.set_ylabel(
            "Amplitude"
        )

        ax1.set_xlim(
            0,
            display_ui
        )

        ax1.grid(
            True,
            alpha=0.25
        )

        # ----------------------------------------------------
        # After FFE
        # ----------------------------------------------------

        x2 = (
            np.arange(
                len(tx_ffe)
            )
            /
            self.samples_per_ui
        )

        ax2.plot(
            x2,
            tx_ffe,
            linewidth=1.2
        )

        ax2.set_title(
            "2. After Tx FFE"
        )

        ax2.set_ylabel(
            "Amplitude"
        )

        ax2.set_xlim(
            0,
            display_ui
        )

        ax2.grid(
            True,
            alpha=0.25
        )

        # ----------------------------------------------------
        # After channel
        # ----------------------------------------------------

        x3 = (
            np.arange(
                len(rx)
            )
            /
            self.samples_per_ui
        )

        ax3.plot(
            x3,
            rx,
            linewidth=1.2
        )

        ax3.set_title(
            "3. After Channel / ISI"
        )

        ax3.set_ylabel(
            "Amplitude"
        )

        ax3.set_xlim(
            0,
            display_ui
        )

        ax3.grid(
            True,
            alpha=0.25
        )

        # ----------------------------------------------------
        # Eye
        # ----------------------------------------------------

        self.draw_eye(
            ax4,
            rx
        )

        self.canvas.fig.tight_layout()

        self.canvas.draw_idle()

        kernel = self.get_ffe_kernel()

        self.status_label.setText(
            "FFE normalized taps: "
            f"C-2={kernel[0]:+.4f}, "
            f"C-1={kernel[1]:+.4f}, "
            f"C0={kernel[2]:+.4f}, "
            f"C+1={kernel[3]:+.4f}"
        )

    # ========================================================
    # UI callbacks
    # ========================================================

    def ffe_changed(
        self,
        name,
        value
    ):

        self.value_labels[
            name
        ].setText(
            str(value)
        )

        if name == "C-2":
            self.cm2 = value

        elif name == "C-1":
            self.cm1 = value

        elif name == "C0":
            self.c0 = value

        elif name == "C+1":
            self.cp1 = value

        self.update_plot()

    def randomize_symbols(self):

        self.symbols = self.generate_pam4()

        self.update_plot()

    def symbol_count_changed(
        self,
        value
    ):

        self.num_symbols = value

        self.symbols = self.generate_pam4()

        self.update_plot()

    def set_ffe_values(
        self,
        cm2,
        cm1,
        c0,
        cp1
    ):

        self.sliders["C-2"].setValue(
            cm2
        )

        self.sliders["C-1"].setValue(
            cm1
        )

        self.sliders["C0"].setValue(
            c0
        )

        self.sliders["C+1"].setValue(
            cp1
        )

    def reset_ffe(self):

        self.set_ffe_values(
            2,
            5,
            50,
            6
        )

    def strong_eq_demo(self):

        self.set_ffe_values(
            5,
            12,
            40,
            15
        )

    def disable_ffe(self):

        self.set_ffe_values(
            0,
            0,
            63,
            0
        )


# ============================================================
# Main
# ============================================================

def main():

    app = QApplication(
        sys.argv
    )

    app.setApplicationName(
        "PCIe Gen6 Tx FFE Visualizer"
    )

    window = MainWindow()

    window.show()

    sys.exit(
        app.exec_()
    )


if __name__ == "__main__":
    main()