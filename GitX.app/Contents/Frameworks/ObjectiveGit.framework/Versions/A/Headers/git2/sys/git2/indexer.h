/*
 * Copyright (C) the libgit2 contributors. All rights reserved.
 *
 * This file is part of libgit2, distributed under the GNU GPL v2 with
 * a Linking Exception. For full terms see the included COPYING file.
 */
#ifndef _INCLUDE_git_indexer_h__
#define _INCLUDE_git_indexer_h__

#include "common.h"
#include "types.h"
#include "oid.h"

GIT_BEGIN_DECL

typedef struct git_indexer git_indexer;

typedef struct git_indexer_options {
	unsigned int version;

	/** progress_cb function to call with progress information */
	git_transfer_progress_cb progress_cb;
	/** progress_cb_payload payload for the progress callback */
	void *progress_cb_payload;

	/** Do connectivity checks for the received pack */
	unsigned char verify;
} git_indexer_options;

#define GIT_INDEXER_OPTIONS_VERSION 1
#define GIT_INDEXER_OPTIONS_INIT { GIT_INDEXER_OPTIONS_VERSION }

/**
 * Initializes a `git_indexer_options` with default values. Equivalent to
 * creating an instance with GIT_INDEXER_OPTIONS_INIT.
 *
 * @param opts the `git_indexer_options` struct to initialize.
 * @param version Version of struct; pass `GIT_INDEXER_OPTIONS_VERSION`
 * @return Zero on success; -1 on failure.
 */
GIT_EXTERN(int) git_indexer_init_options(
	git_indexer_options *opts,
	unsigned int version);

/**
 * Create a new indexer instance
 *
 * @param out where to store the indexer instance
 * @param path to the directory where the packfile should be stored
 * @param mode permissions to use creating packfile or 0 for defaults
 * @param odb object database from which to read base objects when
 * fixing thin packs. Pass NULL if no thin pack is expected (an error
 * will be returned if there are bases missing)
 * @param opts Optional structure containing additional options. See
 * `git_indexer_options` above.
 */
GIT_EXTERN(int) git_indexer_new(
		git_indexer **out,
		const char *path,
		unsigned int mode,
		git_odb *odb,
		git_indexer_options *opts);

/**
 * Add data to the indexer
 *
 * @param idx the indexer
 * @param data the data to add
 * @param size the size of the data in bytes
 * @param stats stat storage
 */
GIT_EXTERN(int) git_indexer_append(git_indexer *idx, const void *data, size_t size, git_transfer_progress *stats);

/**
 * Finalize the pack and index
 *
 * Resolve any pending deltas and write out the index file
 *
 * @param idx the indexer
 */
GIT_EXTERN(int) git_indexer_commit(git_indexer *idx, git_transfer_progress *stats);

/**
 * Get the packfile's hash
 *
 * A packfile's name is derived from the sorted hashing of all object
 * names. This is only correct after the index has been finalized.
 *
 * @param idx the indexer instance
 */
GIT_EXTERN(const git_oid *) git_indexer_hash(const git_indexer *idx);

/**
 * Free the indexer and its resources
 *
 * @param idx the indexer to free
 */
GIT_EXTERN(void) git_indexer_free(git_indexer *idx);

GIT_END_DECL

#endif
