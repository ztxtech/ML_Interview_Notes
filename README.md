# ML Interview Notes

机器学习面试笔记库：把高频面试主题沉淀为结构化、可检索的中文笔记。

仓库地址：<https://github.com/ztxtech/ML_Interview_Notes>

## 目录结构

| 路径 | 说明 |
| --- | --- |
| `notes/` | 主题笔记；每个主题一个子目录，目录内 `README.md` 作入口 |
| `script/` | 仓库维护脚本（个人信息安全检查、Git 钩子） |
| `doc/` | 任务台账与草稿，仅本地保存，不入库 |

## 写作约定

- 中文撰写，术语保留英文原文；公式用 LaTeX，代码块标注语言。
- 文件名使用小写连字符，例如 `notes/deep-learning/transformer-attention.md`。
- 引用外部材料必须附来源链接，不整段复制受版权保护的文本。
- 任何个人身份信息（姓名、邮箱、学校、单位、设备与本地路径）不得入库。

## 提交前安全检查

首次使用先准备个人信息规则（仅本地，不入库；缺失时检查直接失败）：

```bash
cp security/patterns.local.example security/patterns.local
```

然后把占位内容替换为你的真实规则。每次提交前必须通过个人信息安全检查：

```bash
bash script/check_personal_info.sh
```

首次使用建议安装 Git 钩子，此后 `git commit` 会自动检查暂存区：

```bash
bash script/install_git_hooks.sh
```

检查未通过时，先处理全部 `BLOCK` 命中项，再提交。
