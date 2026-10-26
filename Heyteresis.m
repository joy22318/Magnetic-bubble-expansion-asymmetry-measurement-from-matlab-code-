clc
close all 
clear all
T1 = readtable('tapd_0.5_2nmpos_hysteresis.csv');   % or the .csv
% T2 = readtable('sampleboardpostwovoltage_hysteresis.csv');   % or the .csv
% T3 = readtable('sampleboardposfourvoltage_hysteresis.csv');   % or the .csv
% T4 = readtable('sampleboardpossixvoltage_hysteresis.csv');   % or the .csv
% T5 = readtable('sampleboardposeightvoltage_hysteresis.csv');   % or the .csv
% T6 = readtable('sampleboardpostenvoltage_hysteresis.csv');   % or the .csv
M1 = T1.ROI_0;
field1 = T1.Field2_G;
% M2 = T2.ROI_1;
% field2 = T2.Field1_G;
% M3 = T3.ROI_1;
% field3 = T3.Field1_G;
% M4 = T4.ROI_1;
% field4 = T4.Field1_G;
% M5 = T5.ROI_1;
% field5 = T5.Field1_G;
% M6 = T6.ROI_1;
% field6 = T6.Field1_G;

hold on
p1 = plot(field1, M1, '-.', 'Color', [0.85 0.10 0.10], 'LineWidth', 1.5, 'DisplayName', 'V=0V');  % red
% p2 = plot(field2, M2, '-.', 'Color', [0.00 0.45 0.74], 'LineWidth', 1.5, 'DisplayName', 'V=2V');  % blue
% p3 = plot(field3, M3, '-.', 'Color', [0.47 0.67 0.19], 'LineWidth', 1.5, 'DisplayName', 'V=4V');  % green
% p4 = plot(field4, M4, '-.', 'Color', [0.93 0.69 0.13], 'LineWidth', 1.5, 'DisplayName', 'V=6V');  % gold
% p5 = plot(field5, M5, '-.', 'Color', [0.49 0.18 0.56], 'LineWidth', 1.5, 'DisplayName', 'V=8V');  % purple
% p6 = plot(field6, M6, '-.', 'Color', [0.00 0.75 0.75], 'LineWidth', 1.5, 'DisplayName', 'V=10V');  % cyan
hold off

legend('show', 'Location', 'best')
xlabel('Field (G)'); ylabel('M');


hold off
grid on; box on
xlabel('Magnetic field (G)')
ylabel('Brightness/Magnetization')
title('Hysteresis loops vs applied voltage')
% legend(leg, 'Location', 'bestoutside')
set(gca, 'FontSize', 12, 'LineWidth', 1)
xline(0, 'r', 'LineWidth', 1.5);   % x = 0
% yline(0, 'b', 'LineWidth', 1.5);   % y = 0