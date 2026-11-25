# Neovim Configuration with OLLAMA AI Support

Hello world
## Overview
This Neovim configuration includes:
- **Full Python support** via pynvim
- **OLLAMA AI integration** using gemma3:4b model
- Modern plugin management with lazy.nvim
- LSP support with Mason
- Code completion with nvim-cmp
- File navigation with Telescope and nvim-tree

## First Time Setup

1. **Open Neovim** (plugins will auto-install):
   ```bash
   nvim
   ```

2. **Wait for plugins to install** (lazy.nvim will automatically download and setup all plugins)

3. **Install LSP servers** (optional, will auto-install on first use):
   - Open Neovim and type `:Mason`
   - LSP servers for Lua, Python, and TypeScript are already configured

## Key Bindings

### Leader Key
- Leader key is set to `Space`

### AI Commands (OLLAMA)
| Keybinding | Mode | Description |
|------------|------|-------------|
| `<leader>ai` | Normal/Visual | Open AI menu |
| `<leader>ag` | Visual | Generate code from selection |
| `<leader>ac` | Visual | Chat with AI about selection |
| `<leader>ae` | Visual | Enhance selected code |
| `<leader>ar` | Visual | Review selected code |
| `<leader>oo` | Normal/Visual | Ollama prompt |
| `<leader>oG` | Normal/Visual | Ollama generate code |

### File Navigation
| Keybinding | Description |
|------------|-------------|
| `<leader>e` | Toggle file explorer (nvim-tree) |
| `<leader>ff` | Find files (Telescope) |
| `<leader>fg` | Live grep search (Telescope) |
| `<leader>fb` | Find buffers (Telescope) |

### LSP (Language Server)
| Keybinding | Description |
|------------|-------------|
| `gd` | Go to definition |
| `K` | Show hover documentation |
| `<leader>ca` | Code actions |
| `<leader>rn` | Rename symbol |

### Basic Editing
| Keybinding | Description |
|------------|-------------|
| `<leader>w` | Save file |
| `<leader>q` | Quit |
| `gcc` | Toggle comment (line) |
| `gc` | Toggle comment (visual mode) |

### Window Navigation
| Keybinding | Description |
|------------|-------------|
| `<C-h>` | Move to left window |
| `<C-j>` | Move to down window |
| `<C-k>` | Move to up window |
| `<C-l>` | Move to right window |

### Completion (Insert Mode)
| Keybinding | Description |
|------------|-------------|
| `<C-Space>` | Trigger completion |
| `<CR>` | Confirm selection |
| `<Tab>` | Next item / expand snippet |
| `<C-e>` | Abort completion |

## Using OLLAMA AI Features

### Example Workflow:

1. **Generate Code**:
   - Select text in visual mode (`v`)
   - Press `<leader>ag` to generate code

2. **Code Review**:
   - Select your code in visual mode
   - Press `<leader>ar` to get AI review

3. **Ask Questions**:
   - Press `<leader>oo` to open Ollama prompt
   - Type your question and get AI assistance

4. **Enhance Code**:
   - Select code to improve
   - Press `<leader>ae` for AI suggestions

## Python Support

Python support is enabled via:
- `pynvim` package (already installed)
- Pyright LSP for intelligent completions
- Python 3 provider configured

To verify Python support:
```vim
:checkhealth provider
```

## Customization

Edit `~/.config/nvim/init.lua` to:
- Change the OLLAMA model (currently set to `gemma3:4b`)
- Add more LSP servers via Mason
- Customize keybindings
- Add additional plugins

## Plugins Included

- **lazy.nvim** - Plugin manager
- **tokyonight.nvim** - Color scheme
- **nvim-treesitter** - Syntax highlighting
- **telescope.nvim** - Fuzzy finder
- **nvim-lspconfig** - LSP configuration
- **mason.nvim** - LSP installer
- **nvim-cmp** - Autocompletion
- **gen.nvim** - OLLAMA integration
- **ollama.nvim** - Alternative OLLAMA client
- **nvim-tree.lua** - File explorer
- **lualine.nvim** - Status line
- **gitsigns.nvim** - Git integration
- **Comment.nvim** - Easy commenting
- **nvim-autopairs** - Auto close brackets

## Troubleshooting

### OLLAMA not responding
```bash
# Check if OLLAMA is running
brew services list | grep ollama

# Restart OLLAMA if needed
brew services restart ollama
```

### Check Python support
```vim
:checkhealth provider
```

### Update plugins
```vim
:Lazy sync
```

### Check OLLAMA model
```bash
ollama list
```

## Tips

1. Use `:Lazy` to manage plugins
2. Use `:Mason` to install language servers
3. Use `:checkhealth` to diagnose issues
4. Press `<leader>ai` in visual mode to interact with selected code
5. The AI features work best with clear, well-defined code selections
