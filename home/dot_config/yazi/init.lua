-- Keep zoxide's database fresh when directories change in Yazi.
require("zoxide"):setup({
	update_db = true,
})
