<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::table('worker_benefits', function (Blueprint $table) {
            $table->string('health_insurance_desc')->nullable()->after('health_insurance');
            $table->string('food_allowance_desc')->nullable()->after('food_allowance');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('worker_benefits', function (Blueprint $table) {
            $table->dropColumn(['health_insurance_desc', 'food_allowance_desc']);
        });
    }
};
