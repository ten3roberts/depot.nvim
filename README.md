# Depot.nvim

A plugin to load project local settings into a local store.

Unlike other plugins like [nvim-config-local](https://github.com/klen/nvim-config-local) or `exrc` *no code is executed. Rather, a
configuration table is loaded into a global store and can be consumed throughout your config.

Have your config read your settings, rather than the settings modify your config.

## Motivation

When bouncing between different project with different styles and cargo features it is often desired to have different
settings for each project.

There are existing solutions for this, such as `.exrc` and `nvim-config-local` that allow loading lua code. While being
flexible, they suffer security and interoperability issues.

As a result of the configurability of Neovim there are many attack surfaces and code injection. Not only from
_executing_ `exrc` files, but from injecting malicious or ill conceived Neovim options, such as `makeprg` or globals
variables that plugins use to execute commands, or hooks.

Additionally, using a project local script makes it difficult to influence configurations of plugins, often
requiring exposing the plugin config as a global for the `exrc` to modify before calling `setup` on your plugin.

`depot.nvim` mitigates these by loading settings as inert json, and then _publishing_ it to your config,
where you can validate and selectively choose which keys to read and use. You are in control of which settings go where,
rather than dumping them into `globals` or `options`, where options such as `makeprg` or other lsp build scripts can be
set to malicious values.

It allows _consuming_ the most recent settings where and _when_ it is needed, which allows you to load plugins or
configure an LSP hydrated using the keys and values of your choosing when it is needed.
