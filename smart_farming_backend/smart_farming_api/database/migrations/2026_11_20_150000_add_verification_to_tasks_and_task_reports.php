<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('tasks', function (Blueprint $table) {
            $table->string('status', 30)->default('menunggu')->change();
        });

        Schema::table('task_reports', function (Blueprint $table) {
            $table->string('review_status', 20)->default('terverifikasi')->after('reported_at');
            $table->string('reviewer_role', 20)->nullable()->after('review_status');
            $table->timestamp('reviewer_assigned_at')->nullable()->after('reviewer_role');
            $table->foreignId('reviewed_by')->nullable()->after('reviewer_assigned_at')->constrained('users')->nullOnDelete();
            $table->string('reviewed_role', 20)->nullable()->after('reviewed_by');
            $table->timestamp('reviewed_at')->nullable()->after('reviewed_role');
            $table->string('reject_reason')->nullable()->after('reviewed_at');
            $table->string('objection_note')->nullable()->after('reject_reason');
            $table->unsignedTinyInteger('objection_count')->default(0)->after('objection_note');
            $table->boolean('is_final')->default(false)->after('objection_count');
            $table->timestamp('escalated_at')->nullable()->after('is_final');

            $table->index(['company_id', 'review_status', 'reviewer_role']);
        });
    }

    public function down(): void
    {
        Schema::table('task_reports', function (Blueprint $table) {
            $table->dropIndex(['company_id', 'review_status', 'reviewer_role']);
            $table->dropConstrainedForeignId('reviewed_by');
            $table->dropColumn([
                'review_status',
                'reviewer_role',
                'reviewer_assigned_at',
                'reviewed_role',
                'reviewed_at',
                'reject_reason',
                'objection_note',
                'objection_count',
                'is_final',
                'escalated_at',
            ]);
        });
    }
};
