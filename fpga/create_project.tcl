# SET PROJECT NAME
set  project_name Loongson_Soc
set  project_path ./project
set project_part xc7a200tfbg676-1
# CLEAR
file delete -force $project_path

create_project -force $project_name $project_path -part $project_part

# 自动删除 PLL 文件（跨平台）
# 优先尝试 PowerShell Core (`pwsh`)，其次尝试 Windows PowerShell (`powershell`)，
# 最后回退到 POSIX `find`（在 Ubuntu/macOS 等系统上使用）。
# 所有调用均用 `catch` 包裹——若目标文件不存在则静默继续，不会中断后续流程。
set ipdir [file normalize ../rtl/ip]
if {[file isdirectory $ipdir]} {
	# Try PowerShell Core (pwsh)
	if {[catch {
		exec pwsh -NoProfile -Command "Get-ChildItem -Path '$ipdir' -Recurse -Include 'clk_pll_sim_netlist.*','clk_pll_stub.*','*.dcp' | Remove-Item -Force -ErrorAction SilentlyContinue"
	} _err_pwsh]} {
		# Try Windows PowerShell
		if {[catch {
			exec powershell -NoProfile -Command "Get-ChildItem -Path '$ipdir' -Recurse -Include 'clk_pll_sim_netlist.*','clk_pll_stub.*','*.dcp' | Remove-Item -Force -ErrorAction SilentlyContinue"
		} _err_ps]} {
			# Fallback to POSIX find (Linux/macOS)
			if {[catch {
				exec bash -lc "find '$ipdir' -type f \\( -name 'clk_pll_sim_netlist.*' -o -name 'clk_pll_stub.*' -o -name '*.dcp' \\) -print -delete"
			} _err_find]} {
				puts stderr "Warning: 清理 PLL 生成文件时出错（尝试 pwsh/powershell/find 均失败），继续执行：$_err_find"
			}
		}
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
