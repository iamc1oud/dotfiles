# Neovim with VSCode Keybindings + OLLAMA AI

Your Neovim is now configured with VSCode-like keybindings so you don't need to relearn shortcuts!

## Quick Start

```bash
nvim
```

On first launch, plugins will auto-install (takes ~1 minute).

## VSCode Keybindings Reference

### File Operations
| VSCode Shortcut | Description |
|----------------|-------------|
| `Cmd+S` / `Ctrl+S` | Save file |
| `Cmd+W` / `Ctrl+W` | Close tab/buffer |
| `Cmd+Q` / `Ctrl+Q` | Quit all |
| `Cmd+P` / `Ctrl+P` | Quick open (find files) |
| `Cmd+Shift+P` / `Ctrl+Shift+P` | Command palette |

### Editor Actions
| VSCode Shortcut | Description |
|----------------|-------------|
| `Cmd+/` / `Ctrl+/` | Toggle comment |
| `Cmd+Z` / `Ctrl+Z` | Undo |
| `Cmd+Shift+Z` / `Ctrl+Shift+Z` | Redo |
| `Cmd+A` / `Ctrl+A` | Select all |
| `Cmd+C` / `Ctrl+C` | Copy |
| `Cmd+V` / `Ctrl+V` | Paste |
| `Cmd+X` / `Ctrl+X` | Cut |
| `Cmd+F` / `Ctrl+F` | Find in file |

### Navigation
| VSCode Shortcut | Description |
|----------------|-------------|
| `Cmd+B` / `Ctrl+B` | Toggle sidebar (file explorer) |
| `Cmd+Shift+F` / `Ctrl+Shift+F` | Search in all files |
| `Cmd+Shift+O` / `Ctrl+Shift+O` | Go to symbol |
| `Cmd+Shift+[` / `Cmd+Shift+]` | Previous/Next tab |
| `Ctrl+Tab` / `Ctrl+Shift+Tab` | Cycle tabs |

### Code Editing
| VSCode Shortcut | Description |
|----------------|-------------|
| `Alt+Up` / `Alt+Down` | Move line up/down |
| `Shift+Alt+Up` / `Shift+Alt+Down` | Duplicate line |
| `F2` | Rename symbol |
| `Shift+Alt+F` | Format document |

### LSP Features
| VSCode Shortcut | Description |
|----------------|-------------|
| `gd` | Go to definition |
| `gD` | Go to declaration |
| `gi` | Go to implementation |
| `gr` | Find references |
| `K` | Show hover documentation |
| `Ctrl+K` | Signature help |

### Terminal
| VSCode Shortcut | Description |
|----------------|-------------|
| `Ctrl+\`` / `Cmd+\`` | Toggle integrated terminal |

### AI Features (OLLAMA) - WORKING!
| Shortcut | Mode | Description |
|----------|------|-------------|
| `Ctrl+Shift+A` / `Cmd+Shift+A` | Normal | Ask AI any question |
| `Ctrl+Shift+I` / `Cmd+Shift+I` | Visual | AI complete/improve selected code |
| `Ctrl+Shift+E` / `Cmd+Shift+E` | Visual | AI explain selected code |
| `Space+aa` | Normal | Ask AI (alternative) |
| `Space+ac` | Visual | AI complete (alternative) |
| `Space+ae` | Visual | AI explain (alternative) |

## How to Use AI Features

1. **Ask AI Any Question:**
   - Press `Ctrl+Shift+A` (or `Cmd+Shift+A` on Mac)
   - Type your question and press Enter
   - AI response appears in a floating window
   - Press `q` or `Esc` to close

2. **Improve/Complete Code:**
   - Select code in visual mode (`v` to enter, move cursor to select)
   - Press `Ctrl+Shift+I`
   - AI will suggest improvements
   - Response appears in floating window

3. **Explain Code:**
   - Select code in visual mode
   - Press `Ctrl+Shift+E`
   - Get detailed explanation

4. **Alternative (Leader Key):**
   - Press `Space` then `aa` - Ask question
   - Select code, press `Space` then `ac` - Complete code
   - Select code, press `Space` then `ae` - Explain code

## Vim Basics (Still Useful!)

Since this is still Vim/Neovim, you have powerful modal editing:

### Modes
- `i` - Enter insert mode (start typing)
- `Esc` or `jk` or `kj` - Exit insert mode
- `v` - Visual mode (select text)
- `V` - Visual line mode

### Quick Vim Commands
- `dd` - Delete line
- `yy` - Copy line
- `p` - Paste below
- `u` - Undo
- `/search` - Search forward
- `n` - Next search result
- `:w` - Save
- `:q` - Quit

## Customization

Edit `~/.config/nvim/init.lua` to customize anything.

Your original config is backed up at `~/.config/nvim/init.lua.backup`

## Plugins Included

- **vscode.nvim** - VSCode theme
- **lazy.nvim** - Plugin manager
- **nvim-treesitter** - Syntax highlighting
- **telescope.nvim** - Fuzzy finder
- **nvim-lspconfig** - Language servers
- **mason.nvim** - LSP installer
- **nvim-cmp** - Autocompletion
- **bufferline.nvim** - Tab bar (like VSCode)
- **nvim-tree.lua** - File explorer
- **toggleterm.nvim** - Integrated terminal
- **gen.nvim** - OLLAMA integration
- **ollama.nvim** - Alternative OLLAMA client
- **gitsigns.nvim** - Git indicators
- **indent-blankline.nvim** - Indent guides
- **which-key.nvim** - Keybinding hints

## Tips

1. **First Time:** Open Neovim (`nvim`) and wait for plugins to install
2. **File Explorer:** Press `Cmd+B` to toggle sidebar, navigate with arrow keys, press `Enter` to open
3. **Find Files:** Press `Cmd+P`, type filename, `Enter` to open
4. **Search Code:** Press `Cmd+Shift+F`, type search term, `Enter`
5. **AI Help:** Select any code, press `Ctrl+Shift+I` for AI menu
6. **Command Palette:** Press `Cmd+Shift+P` for all available commands

## Troubleshooting

### Check health
```vim
:checkhealth
```

### Update plugins
```vim
:Lazy sync
```

### Install language servers
```vim
:Mason
```

### Check OLLAMA
```bash
brew services list | grep ollama
```

## Differences from Pure VSCode

1. **Modal editing** - Vim's power feature. Press `i` to type, `Esc` to exit
2. **Some shortcuts** may need `Esc` first if you're in insert mode
3. **Terminal** opens at bottom (not as a panel)
4. **No multi-cursor** yet (can be added with vim-visual-multi plugin)

The goal is to make the transition smooth while giving you Vim's power when you need it!
