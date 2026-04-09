# SET PROJECT NAME
set  project_name Loongson_Soc
set  project_path ./project
set project_part xc7a200tfbg676-1
# CLEAR
file delete -force $project_path

create_project -force $project_name $project_path -part $project_part

# 自动删除 PLL 文件（Windows 专用）
# 使用 PowerShell 递归删除仿真网表与 .dcp，适用于在 Windows 环境下运行 Vivado 的情况。
set ipdir [file normalize ../rtl/ip]
if {[file isdirectory $ipdir]} {
	if {[catch {
		exec powershell -NoProfile -Command "Get-ChildItem -Path '$ipdir' -Recurse -Include 'clk_pll_sim_netlist.*','clk_pll_stub.*','*.dcp' | Remove-Item -Force -ErrorAction SilentlyContinue"
	} _err]} {
		puts stderr "Warning: 清理 PLL 生成文件时出错，继续执行：$_err"
	}
}

# Add conventional sources
add_files -scan_for_includes ../rtl

# Add IPs
add_files -norecurse -scan_for_includes ../rtl/ip/PLL_2019_2/clk_pll.xci

# Add simulation files
add_files -fileset sim_1 ../sim/

# Add constraints
add_files -fileset constrs_1 -quiet ./constraints

set_property top soc_top [current_fileset]
set_property -name "top" -value "tb_top" -objects  [get_filesets sim_1]
set_property -name {xsim.simulate.log_all_signals} -value {true} -objects [get_filesets sim_1]
